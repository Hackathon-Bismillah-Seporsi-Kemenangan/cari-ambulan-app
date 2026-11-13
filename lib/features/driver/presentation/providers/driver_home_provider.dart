import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/network/api_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/api_driver_repository.dart';
import '../../data/driver_repository.dart';
import '../../data/routing_repository.dart';
import '../../domain/driver_models.dart';
import '../../domain/route_models.dart';

/// Talks to the Laravel API as the signed-in driver. Recreated per account so
/// no state leaks between logins. Tests override it with a mock.
final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  ref.watch(authProvider.select((auth) => auth.value?.id));
  return ApiDriverRepository(ref.watch(apiClientProvider));
});

final routingRepositoryProvider = Provider<RoutingRepository>(
  (ref) => OsrmRoutingRepository(),
);

/// Driving route between two points, cached while a screen shows it.
///
/// A straight-line estimate (routing unreachable) is retried every
/// [routeRetryInterval], so one failed request doesn't leave the driver
/// without directions until they've moved far enough to re-route.
final routeProvider = FutureProvider.autoDispose
    .family<DriveRoute, ({LatLng from, LatLng to})>((ref, leg) async {
      final route = await ref
          .watch(routingRepositoryProvider)
          .fetchRoute(leg.from, leg.to);
      if (route.isEstimate) {
        final retry = Timer(routeRetryInterval, ref.invalidateSelf);
        ref.onDispose(retry.cancel);
      }
      return route;
    });

const routeRetryInterval = Duration(seconds: 10);

/// How often an open trip is checked for a cancellation by the patient.
const tripCheckInterval = Duration(seconds: 5);

/// Emergency calls offered to the driver; the home page opens the incoming
/// call screen for each one.
final incomingRequestProvider = StreamProvider.autoDispose<EmergencyRequest>(
  (ref) => ref.watch(driverRepositoryProvider).watchIncomingRequests(),
);

final driverHomeProvider =
    AsyncNotifierProvider<DriverHomeNotifier, DriverHomeState>(
      DriverHomeNotifier.new,
    );

class DriverHomeNotifier extends AsyncNotifier<DriverHomeState> {
  DriverRepository get _repo => ref.read(driverRepositoryProvider);

  /// Minimum gap between GPS fixes sent to the server: enough for dispatch.
  static const _reportInterval = Duration(seconds: 10);

  /// During a trip the patient follows the ambulance on a map, so its
  /// position goes out more often.
  static const _tripReportInterval = Duration(seconds: 3);

  /// The GPS only reports movement (5 m), but dispatch drops a driver whose
  /// position is older than 10 minutes, so a parked ambulance re-sends it.
  static const _heartbeatInterval = Duration(minutes: 1);
  DateTime? _lastReportAt;

  @override
  Future<DriverHomeState> build() async {
    // Signed out: the login screen is showing, so load nothing until the
    // next login rebuilds this.
    final userId = ref.watch(authProvider.select((auth) => auth.value?.id));
    if (userId == null) return Completer<DriverHomeState>().future;

    final repo = ref.watch(driverRepositoryProvider);

    // Follow the GPS for as long as the driver screens are alive; the first
    // fix seeds the state.
    final firstLocation = Completer<LatLng>();
    final subscription = repo.watchLocation().listen(
      (location) {
        if (firstLocation.isCompleted) {
          _onLocation(location);
        } else {
          firstLocation.complete(location);
        }
      },
      onError: (Object error) {
        if (!firstLocation.isCompleted) firstLocation.completeError(error);
      },
    );
    ref.onDispose(subscription.cancel);
    final heartbeat = Timer.periodic(_heartbeatInterval, (_) {
      final current = state.value;
      if (current != null && current.isOnline) {
        _report(current.location, throttle: false);
      }
    });
    ref.onDispose(heartbeat.cancel);
    // The patient can cancel at any time; nothing else tells the driver.
    final tripCheck = Timer.periodic(tripCheckInterval, (_) => syncTrip());
    ref.onDispose(tripCheck.cancel);
    final location = await firstLocation.future;

    final (profile, stats, availability, hospital, trip) = await (
      repo.fetchProfile(),
      repo.fetchTodayStats(),
      repo.fetchAvailability(),
      repo.fetchNearestHospital(location),
      repo.fetchActiveTrip(),
    ).wait;

    final home = DriverHomeState(
      profile: profile,
      stats: stats,
      availability: trip == null ? availability : DriverAvailability.busy,
      location: location,
      nearestHospital: hospital,
      trip: trip,
    );
    if (home.isOnline) _report(location);
    return home;
  }

  void _onLocation(LatLng location) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(location: location));
    if (current.isOnline) {
      _report(
        location,
        interval: current.trip == null ? _reportInterval : _tripReportInterval,
      );
    }
  }

  /// Best effort and throttled: dispatch only needs a recent position. The
  /// heartbeat is already spaced out, so it skips the throttle.
  void _report(
    LatLng location, {
    bool throttle = true,
    Duration interval = _reportInterval,
  }) {
    final now = DateTime.now();
    if (throttle &&
        _lastReportAt != null &&
        now.difference(_lastReportAt!) < interval) {
      return;
    }
    _lastReportAt = now;
    _repo.reportLocation(location).catchError((Object _) {});
  }

  /// Flips online/offline. Throws on failure so the UI can show an error;
  /// the previous availability is kept in that case.
  Future<void> toggleOnline() async {
    final current = state.value;
    if (current == null || current.isToggling) return;

    final next = current.isOnline
        ? DriverAvailability.offline
        : DriverAvailability.online;

    state = AsyncData(current.copyWith(isToggling: true));
    try {
      await _repo.setAvailability(next, current.location);
      state = AsyncData(
        current.copyWith(availability: next, isToggling: false),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isToggling: false));
      rethrow;
    }
  }

  /// Claims [request] and marks the driver busy. Throws on failure (e.g. the
  /// order was already taken) so the call screen can tell the driver.
  Future<void> acceptRequest(EmergencyRequest request) async {
    await _repo.acceptRequest(request.id);
    _updateTrip(
      (current) => current.copyWith(
        availability: DriverAvailability.busy,
        trip: ActiveTrip(request: request, acceptedAt: DateTime.now()),
      ),
    );
  }

  /// Marks the pickup reached. Throws on failure so the UI can retry.
  Future<void> markArrivedAtPatient() async {
    final trip = state.value?.trip;
    if (trip == null) return;
    await _repo.markArrivedAtPatient(trip.request.id);
    _updateTrip(
      (current) => current.copyWith(
        trip: current.trip?.copyWith(
          stage: TripStage.atPatient,
          arrivedAt: DateTime.now(),
        ),
      ),
    );
  }

  /// Patient on board: gets the destination hospital from dispatch.
  Future<void> startToHospital() async {
    final current = state.value;
    final trip = current?.trip;
    if (current == null || trip == null) return;
    final hospital = await _repo.startToHospital(
      trip.request.id,
      current.location,
    );
    _updateTrip(
      (current) => current.copyWith(
        trip: current.trip?.copyWith(
          stage: TripStage.toHospital,
          departedToHospitalAt: DateTime.now(),
          hospital: hospital,
        ),
      ),
    );
  }

  /// Closes the order after the IGD handover and puts the driver back online.
  Future<void> completeHandover() async {
    final trip = state.value?.trip;
    if (trip == null) return;
    await _repo.completeHandover(trip.request.id);
    _updateTrip(
      (current) => current.copyWith(
        availability: DriverAvailability.online,
        stats: DriverTodayStats(
          completedTrips: current.stats.completedTrips + 1,
          totalCompletedTrips: switch (current.stats.totalCompletedTrips) {
            final total? => total + 1,
            null => null,
          },
          rating: current.stats.rating,
        ),
        clearTrip: true,
      ),
    );
  }

  /// Closes the open trip when the server says it is over: the patient
  /// cancelled it (kept in [DriverHomeState.cancelledTrip] so the screens can
  /// say so) or it ended elsewhere. Best effort: a failed check waits for
  /// the next one. Also called after a 409, which means this app is stale.
  Future<void> syncTrip() async {
    final trip = state.value?.trip;
    if (trip == null || _isSyncing) return;
    _isSyncing = true;
    try {
      final status = await _repo.checkTrip(trip.request.id);
      if (status == RemoteTripStatus.active) return;
      // The server puts the driver back to its own availability.
      final availability = await _repo.fetchAvailability().catchError(
        (Object _) => DriverAvailability.online,
      );
      _updateTrip((current) {
        // Another trip may have started while this check ran.
        if (current.trip?.request.id != trip.request.id) return current;
        return current.copyWith(
          availability: availability,
          clearTrip: true,
          cancelledTrip: status == RemoteTripStatus.cancelled ? trip : null,
        );
      });
    } catch (_) {
      // Offline: try again on the next tick.
    } finally {
      _isSyncing = false;
    }
  }

  bool _isSyncing = false;

  // Reads the latest state after an await, so concurrent updates aren't lost.
  /// Reloads the profile and trip counts (e.g. pull to refresh on Profil)
  /// without touching availability or the trip in progress.
  Future<void> refreshProfile() async {
    final (profile, stats) = await (
      _repo.fetchProfile(),
      _repo.fetchTodayStats(),
    ).wait;
    _updateTrip((current) => current.copyWith(profile: profile, stats: stats));
  }

  void _updateTrip(DriverHomeState Function(DriverHomeState) update) {
    final current = state.value;
    if (current != null) state = AsyncData(update(current));
  }

  /// Declines (or lets expire) [request]. Best effort: dispatch reassigns
  /// the order on timeout anyway, so failures are ignored.
  Future<void> declineRequest(EmergencyRequest request) async {
    try {
      await _repo.declineRequest(request.id);
    } catch (_) {}
  }
}
