import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/location/location_service.dart';
import '../../../emergency/domain/emergency_models.dart';
import '../providers/driver_home_provider.dart';
import '../providers/driver_trip_provider.dart';
import 'to_hospital_page.dart';
import 'to_patient_page.dart';

/// Full-screen navigation for the accepted trip: to the patient, then to
/// the hospital. Closes itself once the trip is completed or cancelled.
class TripNavigationPage extends ConsumerStatefulWidget {
  const TripNavigationPage({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const TripNavigationPage()),
      );

  @override
  ConsumerState<TripNavigationPage> createState() => _TripNavigationPageState();
}

class _TripNavigationPageState extends ConsumerState<TripNavigationPage> {
  /// Last trip shown, kept so the page doesn't go blank while it closes.
  EmergencyRequestModel? _trip;

  void _close(DriverTripState state) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          state.wasCancelled
              ? 'Order dibatalkan oleh pasien.'
              : 'Order selesai. Anda kembali online. Terima kasih!',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DriverTripState>(driverTripProvider, (prev, next) {
      if ((prev?.hasActiveTrip ?? false) && !next.hasActiveTrip) {
        _close(next);
      } else if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    final tripState = ref.watch(driverTripProvider);
    final trip = _trip = tripState.hasActiveTrip ? tripState.trip : _trip;
    final location = _location();

    final hospital = trip?.hospital;
    final Widget body;
    if (trip == null) {
      body = const SizedBox.shrink();
    } else if (trip.status == EmergencyRequestStatus.enRouteToHospital &&
        hospital != null) {
      body = ToHospitalPage(trip: trip, hospital: hospital, location: location);
    } else {
      body = ToPatientPage(trip: trip, location: location);
    }

    return PopScope(
      // An accepted order can't be abandoned by pressing back.
      canPop: false,
      child: Scaffold(body: body),
    );
  }

  /// Live GPS, else the last position sent to the server.
  LatLng _location() {
    final live = ref.watch(liveLocationProvider).value;
    if (live != null) return live;
    final home = ref.watch(driverHomeProvider).value;
    return LatLng(
      home?.lastBeaconLatitude ?? LocationService.defaultLatitude,
      home?.lastBeaconLongitude ?? LocationService.defaultLongitude,
    );
  }
}
