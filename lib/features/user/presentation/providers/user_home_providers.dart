import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/logging/app_log.dart';
import '../../../../core/network/api_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../call/domain/call_models.dart';
import '../../data/api_user_repository.dart';
import '../../data/user_repository.dart';
import '../../domain/user_models.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final userId = ref.watch(authProvider.select((auth) => auth.value?.id));
  return ApiUserRepository(ref.watch(apiClientProvider), userId: userId);
});

final locationServiceProvider = Provider((ref) => LocationService());

/// The user's GPS position while the home screen is open.
final userLocationProvider = StreamProvider.autoDispose<LocationFix>(
  (ref) => ref.watch(locationServiceProvider).watchFix(),
);

/// Where the user was last time, to open the map there before GPS answers.
final savedLocationProvider = FutureProvider.autoDispose<LatLng?>(
  (ref) => ref.watch(locationServiceProvider).lastSaved(),
);

/// Street address of the current position, for the pickup card.
final pickupAddressProvider = FutureProvider.autoDispose<String?>((ref) async {
  final point = await ref.watch(
    userLocationProvider.selectAsync((fix) => fix.point),
  );
  return ref.watch(userRepositoryProvider).addressOf(point);
});

/// The closest available ambulance, refreshed every [_refreshEvery] and
/// whenever the user moves. Keeps the last answer when a refresh fails.
final nearestAmbulanceProvider = StreamProvider.autoDispose<NearestAmbulance?>((
  ref,
) async* {
  final point = await ref.watch(
    userLocationProvider.selectAsync((fix) => fix.point),
  );
  final repo = ref.watch(userRepositoryProvider);
  while (true) {
    try {
      yield await repo.fetchNearestAmbulance(point);
    } catch (e) {
      AppLog.warn('Beranda', 'Nearest ambulance unavailable', e);
    }
    await Future<void>.delayed(_refreshEvery);
  }
});

const _refreshEvery = Duration(seconds: 15);

/// The driver calling this user, while the tracking screen is open.
final incomingCallProvider = StreamProvider.autoDispose<IncomingCall?>(
  (ref) => ref.watch(userRepositoryProvider).watchIncomingCall(),
);

/// Live progress of the user's emergency request, polled every 3 s.
final emergencySearchProvider = StreamProvider.autoDispose
    .family<EmergencySearch, String>(
      (ref, id) => ref.watch(userRepositoryProvider).watchEmergency(id),
    );

/// "Tujuan" on the search screen.
final nearestHospitalNameProvider = FutureProvider.autoDispose
    .family<String?, LatLng>(
      (ref, from) =>
          ref.watch(userRepositoryProvider).nearestHospitalName(from),
    );

/// The Medical ID, for its tab, Profil and the readiness score.
final medicalProfileProvider = FutureProvider<Synced<MedicalProfile>>(
  (ref) => ref.watch(userRepositoryProvider).fetchMedicalProfile(),
);

final savedAddressesProvider = FutureProvider<Synced<List<SavedAddress>>>(
  (ref) => ref.watch(userRepositoryProvider).fetchAddresses(),
);

/// Riwayat; refreshed when the tab is pulled down.
final emergencyHistoryProvider = FutureProvider<List<EmergencyHistoryItem>>(
  (ref) => ref.watch(userRepositoryProvider).fetchHistory(),
);
