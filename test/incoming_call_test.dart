import 'package:cari_ambulan/features/driver/domain/driver_models.dart';
import 'package:cari_ambulan/features/driver/presentation/pages/incoming_call_page.dart';
import 'package:cari_ambulan/features/driver/presentation/widgets/availability_card.dart';
import 'package:cari_ambulan/features/driver/data/mock_driver_repository.dart';
import 'package:cari_ambulan/features/driver/data/routing_repository.dart';
import 'package:cari_ambulan/features/driver/domain/route_models.dart';
import 'package:cari_ambulan/features/driver/presentation/providers/driver_home_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'test_app.dart';

EmergencyRequest _request({Duration window = const Duration(seconds: 30)}) {
  final now = DateTime.now();
  return EmergencyRequest(
    id: 'order-1',
    reporterName: 'Siti Rahmawati',
    reporterPhone: '+6281234567890',
    condition: 'Jantung',
    symptom: 'Nyeri dada',
    patientCount: 1,
    pickupAddress: 'Jl. Sudirman No. 21, Jakarta Pusat',
    pickupDetail: 'Lobby Wisma 46, lantai dasar',
    pickupLocation: const LatLng(-6.2245, 106.8125),
    distanceKm: 2.4,
    etaMinutes: 6,
    nearestHospitalName: 'RS Medika',
    bloodType: 'O+',
    allergy: 'Alergi penisilin',
    note: 'Kami tunggu di lobby',
    offeredAt: now,
    expiresAt: now.add(window),
  );
}

void main() {
  Future<List<bool?>> pumpCall(
    WidgetTester tester, {
    required EmergencyRequest request,
    required List<String> calls,
  }) async {
    final results = <bool?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              results.add(
                await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => IncomingCallPage(
                      request: request,
                      onAccept: () async => calls.add('accept'),
                      onDecline: () async => calls.add('decline'),
                    ),
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return results;
  }

  testWidgets('shows order details and accepts', (tester) async {
    final calls = <String>[];
    final results = await pumpCall(tester, request: _request(), calls: calls);

    expect(find.text('PANGGILAN DARURAT'), findsOneWidget);
    expect(find.text('Jantung · Nyeri dada'), findsOneWidget);
    expect(find.text('Jl. Sudirman No. 21, Jakarta Pusat'), findsOneWidget);
    expect(find.text('2.4 km'), findsOneWidget);
    expect(find.text('6 menit'), findsOneWidget);

    await tester.tap(find.text('Terima'));
    await tester.pumpAndSettle();

    expect(calls, ['accept']);
    expect(results, [true]);
  });

  testWidgets('declines automatically when time runs out', (tester) async {
    final calls = <String>[];
    final results = await pumpCall(
      tester,
      request: _request(window: const Duration(seconds: 3)),
      calls: calls,
    );

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(calls, ['decline']);
    expect(results, [false]);
  });

  testWidgets('going online opens the incoming call screen', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump(); // resolve the signed-in session
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byType(PowerSwitch));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('ONLINE'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('PANGGILAN DARURAT'), findsOneWidget);

    await tester.tap(find.text('Tolak'));
    await tester.pump(const Duration(seconds: 1)); // decline request
    await tester.pump(const Duration(seconds: 1)); // close transition
    expect(find.text('PANGGILAN DARURAT'), findsNothing);

    // Going offline cancels the mock's next scheduled call.
    await tester.tap(find.byType(PowerSwitch));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('OFFLINE'), findsOneWidget);
  });

  testWidgets('accepting opens the route to the patient', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          routingRepositoryProvider.overrideWithValue(_FakeRouting()),
        ],
      ),
    );
    await tester.pump(); // resolve the signed-in session
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byType(PowerSwitch));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Terima'));
    await tester.pump(const Duration(seconds: 1)); // accept request
    await tester.pump(const Duration(seconds: 1)); // page transitions
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Menuju pasien'), findsOneWidget);
    expect(find.text('Siti Rahmawati'), findsOneWidget);
    expect(find.text('Belok kanan ke Jl. Thamrin'), findsOneWidget);
    expect(find.text('300 m'), findsOneWidget);

    await tester.tap(find.text('Saya Sudah Tiba'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Tiba di lokasi pasien'), findsOneWidget);

    await tester.tap(find.text('Mulai ke Rumah Sakit'));
    await tester.pump(const Duration(seconds: 2)); // hospital assignment
    await tester.pump(const Duration(seconds: 1)); // page transition

    expect(find.text('Menuju rumah sakit'), findsNWidgets(2)); // title + step
    expect(find.text('RS Medika sudah diberi tahu'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);

    await tester.tap(find.text('Serahkan Pasien ke IGD'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Ya, Serahkan'));
    await tester.pump(const Duration(seconds: 1)); // complete handover
    await tester.pump(const Duration(seconds: 1)); // close transition

    expect(find.text('Menuju rumah sakit'), findsNothing);
    expect(find.text('ONLINE'), findsOneWidget);
    expect(find.text('5'), findsOneWidget); // trips completed today

    // Going offline cancels the mock's next scheduled call.
    await tester.tap(find.byType(PowerSwitch));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a cancellation by the patient closes the trip and says so', (
    tester,
  ) async {
    final repo = _CancellingDriverRepository();
    await tester.pumpWidget(
      testApp(
        driverRepository: repo,
        overrides: [
          routingRepositoryProvider.overrideWithValue(_FakeRouting()),
        ],
      ),
    );
    await tester.pump(); // resolve the signed-in session
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byType(PowerSwitch));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Terima'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Menuju pasien'), findsOneWidget);

    repo.cancelled = true;
    await tester.pump(tripCheckInterval);
    await tester.pump(const Duration(seconds: 1)); // close the trip screen
    await tester.pump(const Duration(seconds: 1)); // dialog

    expect(find.text('Order dibatalkan pasien'), findsOneWidget);
    expect(find.text('Menuju pasien'), findsNothing);

    await tester.tap(find.text('Mengerti'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1)); // close transition
    expect(find.text('Order dibatalkan pasien'), findsNothing);
    expect(find.text('ONLINE'), findsOneWidget);

    // Going offline cancels the mock's next scheduled call.
    await tester.tap(find.byType(PowerSwitch));
    await tester.pump(const Duration(seconds: 1));
  });
}

/// Reports the open trip as cancelled once [cancelled] is set.
class _CancellingDriverRepository extends MockDriverRepository {
  bool cancelled = false;

  @override
  Future<RemoteTripStatus> checkTrip(String requestId) async =>
      cancelled ? RemoteTripStatus.cancelled : RemoteTripStatus.active;
}

class _FakeRouting implements RoutingRepository {
  @override
  Future<DriveRoute> fetchRoute(LatLng from, LatLng to) async => DriveRoute(
    points: [from, to],
    distanceMeters: 1800,
    duration: const Duration(minutes: 5),
    steps: [
      RouteStep(
        maneuver: Maneuver.depart,
        streetName: '',
        distanceMeters: 300,
        location: from,
      ),
      RouteStep(
        maneuver: Maneuver.right,
        streetName: 'Jl. Thamrin',
        distanceMeters: 1500,
        location: to,
      ),
    ],
  );
}
