import 'dart:async';

import 'package:cari_ambulan/features/call/presentation/widgets/active_call_sheet.dart';
import 'package:cari_ambulan/core/location/location_service.dart';
import 'package:cari_ambulan/features/auth/domain/auth_models.dart';
import 'package:cari_ambulan/features/call/domain/call_models.dart';
import 'package:cari_ambulan/features/user/data/user_repository.dart';
import 'package:cari_ambulan/features/user/domain/user_models.dart';
import 'package:cari_ambulan/features/user/presentation/providers/user_home_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'test_app.dart';

const _patient = AuthUser(
  id: 'user-1',
  fullName: 'Siti Rahmawati',
  email: 'pasien@cariambulan.id',
  roles: ['user'],
);

class _FakeUserRepository implements UserRepository {
  _FakeUserRepository({this.ambulance, this.open});

  final NearestAmbulance? ambulance;

  /// The request still running from an earlier session, if any.
  EmergencySearch? open;
  final created = <EmergencySearch>[];
  final createdTypes = <EmergencyType>[];
  final cancelled = <String>[];
  final cancelReasons = <String?>[];
  final driverCalls = <String>[];
  final widenedTo = <double>[];
  int retries = 0;
  MedicalProfile medical = MedicalProfile.empty;
  List<EmergencyHistoryItem> history = const [];
  final _updates = StreamController<EmergencySearch>.broadcast();

  /// Pushes a new poll result to the search screen.
  void emit(EmergencySearch search) => _updates.add(search);

  @override
  Future<NearestAmbulance?> fetchNearestAmbulance(LatLng from) async =>
      ambulance;

  @override
  Future<String?> addressOf(LatLng point) async => 'Jl. Sudirman No. 21';

  @override
  Future<String?> nearestHospitalName(LatLng from) async => 'RS Medika';

  @override
  Future<EmergencySearch> createEmergency({
    required LatLng pickup,
    required String address,
    required bool forSelf,
    required EmergencyType type,
  }) async {
    final search = _search(pickupAddress: address, pickup: pickup);
    created.add(search);
    createdTypes.add(type);
    return search;
  }

  @override
  Future<EmergencySearch?> fetchOpenEmergency() async => open;

  @override
  Stream<EmergencySearch> watchEmergency(String id) => _updates.stream;

  @override
  Stream<IncomingCall?> watchIncomingCall() => const Stream.empty();

  @override
  Future<EmergencySearch> cancelEmergency(String id, {String? reason}) async {
    cancelled.add(id);
    cancelReasons.add(reason);
    return _search(status: EmergencySearchStatus.cancelled);
  }

  @override
  Future<EmergencySearch> expandSearchRadius(String id, double radiusKm) async {
    widenedTo.add(radiusKm);
    return _search(searchRadiusKm: radiusKm);
  }

  @override
  Future<EmergencySearch> retrySearch(String id) async {
    retries++;
    return _search(searchRadiusKm: SearchRadius.maxKm);
  }

  @override
  Future<void> callDriver(String requestId) async => driverCalls.add(requestId);

  @override
  Future<List<EmergencyHistoryItem>> fetchHistory() async => history;

  @override
  Future<Synced<MedicalProfile>> fetchMedicalProfile() async =>
      (value: medical, synced: true);

  @override
  Future<bool> saveMedicalProfile(MedicalProfile profile) async {
    medical = profile;
    return true;
  }

  @override
  Future<Synced<List<SavedAddress>>> fetchAddresses() async =>
      (value: const <SavedAddress>[], synced: true);

  @override
  Future<bool> addAddress(SavedAddress address) async => true;

  @override
  Future<({String fullName, String? phone})> updateProfile({
    required String fullName,
    required String phone,
  }) async => (fullName: fullName, phone: phone);
}

EmergencySearch _search({
  EmergencySearchStatus status = EmergencySearchStatus.searching,
  TripStage stage = TripStage.toPickup,
  TripInfo? trip,
  int driversContacted = 0,
  double? searchRadiusKm,
  bool? searchExhausted,
  String pickupAddress = 'Jl. Sudirman No. 21',
  LatLng pickup = const LatLng(-8.1724, 113.7008),
}) => EmergencySearch(
  id: 'req-1',
  code: 'CA-TEST01',
  status: status,
  emergencyType: 'Lainnya',
  pickup: pickup,
  pickupAddress: pickupAddress,
  driversContacted: driversContacted,
  nearbyAmbulances: const [LatLng(-8.1786, 113.6986)],
  stage: stage,
  trip: trip,
  searchRadiusKm: searchRadiusKm,
  searchExhausted: searchExhausted,
);

const _trip = TripInfo(
  driverName: 'Budi Santoso',
  driverRating: 4.9,
  driverTripCount: 1240,
  plateNumber: 'B 1199 SGM',
  vehicleType: 'Ambulans ALS',
  ambulanceLocation: LatLng(-8.1786, 113.6986),
  etaMinutes: 5,
  distanceKm: 1.8,
);

class _FakeLocation extends LocationService {
  @override
  Future<LatLng?> lastSaved() async => null;

  @override
  Stream<LocationFix> watchFix() => Stream.value((
    point: const LatLng(-8.1724, 113.7008),
    accuracyMeters: 10,
  ));
}

/// Location off: only the fallback city, and no fix when asked again.
class _NoGps extends LocationService {
  @override
  Future<LatLng?> lastSaved() async => null;

  @override
  Stream<LocationFix> watchFix() =>
      Stream.value((point: LocationService.fallback, accuracyMeters: null));

  @override
  Future<LocationFix?> currentFix() async => null;
}

void main() {
  late _FakeUserRepository repo;

  Future<void> pumpHome(
    WidgetTester tester, {
    NearestAmbulance? ambulance,
    EmergencySearch? open,
    MedicalProfile medical = MedicalProfile.empty,
    List<EmergencyHistoryItem> history = const [],
    LocationService? location,
  }) async {
    repo = _FakeUserRepository(ambulance: ambulance, open: open)
      ..medical = medical
      ..history = history;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      testApp(
        user: _patient,
        overrides: [
          userRepositoryProvider.overrideWithValue(repo),
          locationServiceProvider.overrideWithValue(
            location ?? _FakeLocation(),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // The map is built once the first GPS fix is in.
    await tester.pump();
  }

  /// Unmounts the app so the 15 s refresh loop and animations stop.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 16));
  }

  testWidgets('a user account opens the patient home screen', (tester) async {
    await pumpHome(
      tester,
      ambulance: const NearestAmbulance(
        location: LatLng(-8.1786, 113.6986),
        distanceKm: 1.4,
        etaMinutes: 4,
      ),
    );

    expect(find.text('Lokasi kamu · GPS ±10 m'), findsOneWidget);
    expect(find.text('Jl. Sudirman No. 21'), findsOneWidget);
    expect(find.text('Ambulans terdekat ±4 menit'), findsOneWidget);
    expect(find.text('4 mnt'), findsOneWidget);
    expect(find.text('PANGGIL\nAMBULANS'), findsOneWidget);
    expect(find.text('Telepon 119'), findsOneWidget);
    expect(find.text('Medical ID'), findsOneWidget);
    expect(find.text('SR'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('says so when no ambulance is available', (tester) async {
    await pumpHome(tester);

    expect(find.text('Belum ada ambulans tersedia di sekitar'), findsOneWidget);

    await unmount(tester);
  });

  /// Presses PANGGIL AMBULANS for [duration] and keeps holding.
  Future<TestGesture> pressCallButton(
    WidgetTester tester, {
    Duration duration = const Duration(seconds: 2),
  }) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('PANGGIL\nAMBULANS')),
    );
    // The ring starts filling on the first frame.
    await tester.pump();
    await tester.pump(duration);
    // The popup opens on the next frames.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    return gesture;
  }

  /// Presses PANGGIL AMBULANS for [duration], then lets go where it is.
  Future<void> holdCallButton(
    WidgetTester tester, {
    Duration duration = const Duration(seconds: 2),
  }) async {
    final gesture = await pressCallButton(tester, duration: duration);
    await gesture.up();
    await tester.pump();
  }

  /// Still holding, slides onto [label] and lets go there.
  Future<void> slideTo(
    WidgetTester tester,
    TestGesture gesture,
    String label,
  ) async {
    await gesture.moveTo(tester.getCenter(find.text(label)));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('a short press sends nothing', (tester) async {
    await pumpHome(tester);
    expect(find.text('Tekan & tahan 2 detik untuk memanggil'), findsOneWidget);

    await holdCallButton(tester, duration: const Duration(seconds: 1));
    expect(find.text('Apa kondisi daruratnya?'), findsNothing);

    await tester.pump(const Duration(seconds: 6));
    expect(repo.created, isEmpty);

    await unmount(tester);
  });

  testWidgets('sliding onto a condition and letting go calls with it', (
    tester,
  ) async {
    await pumpHome(tester);

    final gesture = await pressCallButton(tester);
    expect(find.text('Apa kondisi daruratnya?'), findsOneWidget);
    expect(
      find.text('Geser ke kondisi pasien, lalu lepaskan.'),
      findsOneWidget,
    );
    // No countdown while the finger is still choosing.
    await tester.pump(const Duration(seconds: 6));
    expect(repo.created, isEmpty);

    await slideTo(tester, gesture, 'Henti jantung');

    expect(repo.createdTypes, [EmergencyType.hentiJantung]);
    expect(find.text('Apa kondisi daruratnya?'), findsNothing);
    expect(find.text('Mencari ambulans terdekat...'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('sliding back to the middle picks nothing', (tester) async {
    await pumpHome(tester);

    final gesture = await pressCallButton(tester);
    final middle = tester.getCenter(find.text('Geser'));
    await gesture.moveTo(tester.getCenter(find.text('Kecelakaan')));
    await tester.pump();
    expect(find.text('Lepas untuk\nmemanggil'), findsOneWidget);

    await gesture.moveTo(middle);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(repo.created, isEmpty);
    expect(find.text('Batal'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('letting go in the middle keeps the wheel open to tap', (
    tester,
  ) async {
    await pumpHome(tester);

    // The wheel opens around the finger: letting go without sliding picks
    // nothing.
    await holdCallButton(tester);
    expect(repo.created, isEmpty);
    expect(
      find.text(
        'Ketuk kondisi pasien. Ambulans dipanggil otomatis dalam 5 detik '
        'jika tidak ada jawaban.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Kecelakaan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repo.createdTypes, [EmergencyType.kecelakaan]);

    await unmount(tester);
  });

  testWidgets('"Batal" on the popup sends nothing', (tester) async {
    await pumpHome(tester);

    await holdCallButton(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('dalam 3 detik'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Apa kondisi daruratnya?'), findsNothing);
    expect(repo.created, isEmpty);

    await unmount(tester);
  });

  testWidgets('a finger that slipped off can slide again and pick', (
    tester,
  ) async {
    await pumpHome(tester);

    // Lifted by accident in the middle: the wheel stays.
    await holdCallButton(tester);
    final middle = tester.getCenter(find.text('Batal'));

    // A new touch in the middle, slid onto a condition, picks it.
    final retry = await tester.startGesture(middle);
    await tester.pump();
    expect(find.text('Geser'), findsOneWidget);
    await retry.moveTo(tester.getCenter(find.text('Sesak napas')));
    await tester.pump();
    expect(find.text('Lepas untuk\nmemanggil'), findsOneWidget);
    await retry.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repo.createdTypes, [EmergencyType.sesakNafas]);

    await unmount(tester);
  });

  testWidgets('a tap anywhere on a segment picks it', (tester) async {
    await pumpHome(tester);

    await holdCallButton(tester);
    // The outer edge of the top segment, away from its icon and name.
    final middle = tester.getCenter(find.text('Batal'));
    await tester.tapAt(middle - const Offset(0, 140));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repo.createdTypes, [EmergencyType.kecelakaan]);

    await unmount(tester);
  });

  testWidgets('the countdown waits while a finger is on the wheel', (
    tester,
  ) async {
    await pumpHome(tester);

    await holdCallButton(tester);
    await tester.pump(const Duration(seconds: 3));
    final middle = tester.getCenter(find.text('Batal'));
    final finger = await tester.startGesture(middle);
    await tester.pump(const Duration(seconds: 6));
    expect(repo.created, isEmpty);

    // Moved and let go in the middle: open again, with the full 5 s.
    await finger.moveTo(middle + const Offset(0, 20));
    await finger.up();
    await tester.pump();
    expect(find.textContaining('dalam 5 detik'), findsOneWidget);
    expect(repo.created, isEmpty);

    await unmount(tester);
  });

  testWidgets('a touch Android cancels never picks', (tester) async {
    await pumpHome(tester);

    final gesture = await pressCallButton(tester);
    await gesture.moveTo(tester.getCenter(find.text('Henti jantung')));
    await tester.pump();
    await gesture.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repo.created, isEmpty);
    expect(find.text('Apa kondisi daruratnya?'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('a shaky finger drifting off the button keeps the hold', (
    tester,
  ) async {
    await pumpHome(tester);

    final start = tester.getCenter(find.text('PANGGIL\nAMBULANS'));
    final gesture = await tester.startGesture(start);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    // Past the button's edge (112 dp), within the slack.
    await gesture.moveTo(start + const Offset(140, 0));
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Apa kondisi daruratnya?'), findsOneWidget);

    await gesture.up();
    await unmount(tester);
  });

  testWidgets('letting go too early says to hold longer', (tester) async {
    await pumpHome(tester);

    await holdCallButton(tester, duration: const Duration(milliseconds: 300));
    expect(find.text('Tahan sampai lingkaran penuh'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Tekan & tahan 2 detik untuk memanggil'), findsOneWidget);
    expect(repo.created, isEmpty);

    await unmount(tester);
  });

  testWidgets('back on the popup sends nothing', (tester) async {
    await pumpHome(tester);

    await holdCallButton(tester);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));

    expect(find.text('Apa kondisi daruratnya?'), findsNothing);
    expect(find.text('Tekan & tahan 2 detik untuk memanggil'), findsOneWidget);
    expect(repo.created, isEmpty);

    await unmount(tester);
  });

  testWidgets('lifting the finger after back is not "hold longer"', (
    tester,
  ) async {
    await pumpHome(tester);

    final gesture = await pressCallButton(tester);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(find.text('Apa kondisi daruratnya?'), findsNothing);
    expect(find.text('Tahan sampai lingkaran penuh'), findsNothing);
    expect(repo.created, isEmpty);

    await unmount(tester);
  });

  testWidgets('with no answer the call is sent after 5 s', (tester) async {
    await pumpHome(tester);

    await holdCallButton(tester);
    expect(find.text('Apa kondisi daruratnya?'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repo.created.single.pickupAddress, 'Jl. Sudirman No. 21');
    expect(repo.createdTypes, [EmergencyType.lainnya]);
    expect(find.text('Mencari ambulans terdekat...'), findsOneWidget);
    expect(
      find.text('Jangan tutup aplikasi · lokasi Anda terkirim'),
      findsOneWidget,
    );
    // Starts at 3 km; the ambulance 0.7 km away is in range.
    expect(find.text('1 ambulans siaga dalam 3\u00A0km'), findsOneWidget);
    expect(find.text('Otomatis meluas tiap 20 dtk'), findsOneWidget);

    repo.emit(_search(driversContacted: 3, searchRadiusKm: 5));
    await tester.pump();
    expect(find.text('3/3', findRichText: true), findsOneWidget);
    expect(find.text('3 ambulans siaga dalam 5\u00A0km'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('without GPS the call is not sent to the fallback city', (
    tester,
  ) async {
    await pumpHome(tester, location: _NoGps());

    await holdCallButton(tester);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repo.created, isEmpty);
    expect(find.text('Lokasi tidak ditemukan'), findsOneWidget);
    expect(find.text('Aktifkan lokasi'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Telepon 119'),
      ),
      findsOneWidget,
    );

    await unmount(tester);
  });

  testWidgets('cancelling the search returns to Beranda', (tester) async {
    await pumpHome(tester, open: _search());
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Mencari ambulans terdekat...'), findsOneWidget);

    await tester.tap(find.text('Batalkan'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Ya, Batalkan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repo.cancelled, ['req-1']);
    expect(find.text('Mencari ambulans terdekat...'), findsNothing);
    expect(find.text('PANGGIL\nAMBULANS'), findsOneWidget);

    // The next poll says "cancelled" too; Beranda must stay.
    repo.emit(_search(status: EmergencySearchStatus.cancelled));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('PANGGIL\nAMBULANS'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('follows the ambulance once a driver accepts', (tester) async {
    await pumpHome(tester, open: _search());
    await tester.pump(const Duration(milliseconds: 500));

    repo.emit(_search(status: EmergencySearchStatus.found, trip: _trip));
    await tester.pump();

    expect(
      find.text('Driver ditemukan! Ambulans menuju lokasi Anda.'),
      findsOneWidget,
    );
    expect(find.text('Ambulans menuju lokasi Anda'), findsOneWidget);
    expect(find.text('Tiba dalam 5 menit · 1.8 km'), findsOneWidget);
    expect(find.text('Langkah 3/5'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('4.9 · 1.240 trip'), findsOneWidget);
    expect(find.text('B 1199 SGM'), findsOneWidget);
    expect(find.text('ALS · Gawat Darurat'), findsOneWidget);
    expect(find.text('5 menit'), findsOneWidget);
    expect(find.text('Radius pencarian'), findsNothing);

    // No phone number from the server: rings the driver's app. The call
    // panel opens and the call itself is created once, by the call provider.
    await tester.tap(find.text('Telepon'));
    await tester.pump();
    expect(find.byType(ActiveCallSheet), findsOneWidget);
    expect(repo.driverCalls, isEmpty);

    repo.emit(
      _search(
        status: EmergencySearchStatus.found,
        stage: TripStage.arrived,
        trip: _trip,
      ),
    );
    await tester.pump();
    expect(find.text('Ambulans telah tiba'), findsOneWidget);
    expect(
      find.text('Cari plat B 1199 SGM di depan Jl. Sudirman No. 21'),
      findsOneWidget,
    );
    expect(find.text('Telah tiba'), findsOneWidget);
    expect(find.text('Langkah 4/5'), findsOneWidget);
    // Too late to cancel once the ambulance is there.
    expect(find.text('Batalkan'), findsNothing);

    await unmount(tester);
  });

  testWidgets('follows the ambulance to the hospital', (tester) async {
    await pumpHome(tester, open: _search());
    await tester.pump(const Duration(milliseconds: 500));

    repo.emit(
      _search(
        status: EmergencySearchStatus.found,
        stage: TripStage.toHospital,
        trip: const TripInfo(
          driverName: 'Budi Santoso',
          plateNumber: 'B 1199 SGM',
          ambulanceLocation: LatLng(-8.1724, 113.7008),
          hospitalName: 'RS Medika',
          hospitalLocation: LatLng(-8.1933, 113.7081),
          hospitalPreparation: 'IGD menyiapkan tim trauma.',
          hospitalEntrance: 'Gerbang B',
          etaMinutes: 7,
          distanceKm: 3.2,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Menuju rumah sakit'), findsNWidgets(2));
    expect(
      find.text('Tujuan: RS Medika · Tiba dalam 7 menit · 3.2 km'),
      findsOneWidget,
    );
    expect(find.text('RS Medika sudah diberi tahu'), findsOneWidget);
    expect(
      find.text('IGD menyiapkan tim trauma. Pintu masuk ambulans: Gerbang B.'),
      findsOneWidget,
    );
    // No "found" toast on this leg.
    expect(
      find.text('Driver ditemukan! Ambulans menuju lokasi Anda.'),
      findsNothing,
    );
    expect(find.text('Langkah 5/5'), findsOneWidget);

    // Back doesn't drop the tracking mid-trip.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('RS Medika sudah diberi tahu'), findsOneWidget);

    // Handover at the IGD closes the trip with a message.
    repo.emit(_search(status: EmergencySearchStatus.completed));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('RS Medika sudah diberi tahu'), findsNothing);
    expect(
      find
          .text(
            'Pasien telah diserahkan ke IGD RS Medika. Semoga lekas sembuh!',
          )
          .hitTestable(),
      findsOneWidget,
    );

    await unmount(tester);
  });

  testWidgets('cancelling a coming ambulance needs a reason', (tester) async {
    await pumpHome(
      tester,
      open: _search(status: EmergencySearchStatus.found, trip: _trip),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Batalkan'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Batalkan pesanan ambulans?'), findsOneWidget);
    expect(
      find.textContaining('Ambulans tinggal 5 menit lagi.'),
      findsOneWidget,
    );

    // Nothing happens without a reason.
    await tester.tap(find.text('Ya, Batalkan'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.cancelled, isEmpty);

    await tester.tap(find.text('Salah lokasi'));
    await tester.pump();
    await tester.tap(find.text('Ya, Batalkan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repo.cancelReasons, ['Salah lokasi']);
    expect(find.text('PANGGIL\nAMBULANS'), findsOneWidget);

    repo.emit(_search(status: EmergencySearchStatus.cancelled));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('PANGGIL\nAMBULANS'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('the search widens with the server up to 25 km', (tester) async {
    await pumpHome(tester, open: _search(searchRadiusKm: 5));
    await tester.pump(const Duration(milliseconds: 500));

    // The picker shows the previous, current and next step.
    expect(find.bySemanticsLabel('Radius 3\u00A0km'), findsOneWidget);
    expect(find.bySemanticsLabel('Radius 5\u00A0km'), findsOneWidget);
    expect(find.bySemanticsLabel('Radius 10\u00A0km'), findsOneWidget);
    expect(find.bySemanticsLabel('Radius 15\u00A0km'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Radius 10\u00A0km'));
    await tester.pump();
    expect(repo.widenedTo, [10]);

    // The server widens past 10 km on its own; the screen follows it.
    repo.emit(_search(searchRadiusKm: 15));
    await tester.pump();
    expect(find.bySemanticsLabel('Radius 15\u00A0km'), findsOneWidget);
    expect(find.text('1 ambulans siaga dalam 15\u00A0km'), findsOneWidget);

    repo.emit(_search(searchRadiusKm: 25));
    await tester.pump();
    // 25 km is the last step: the picker ends there.
    expect(find.bySemanticsLabel('Radius 25\u00A0km'), findsOneWidget);
    expect(find.text('1 ambulans siaga dalam 25\u00A0km'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('says so when nobody accepted within 25 km', (tester) async {
    await pumpHome(
      tester,
      open: _search(driversContacted: 9, searchExhausted: true),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Belum ada ambulans tersedia'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('radius maks'), findsOneWidget);
    expect(find.text('Telepon 119 Sekarang'), findsOneWidget);
    expect(find.text('Kontak darurat'), findsOneWidget);

    await tester.tap(find.text('Cari Lagi · radius 25\u00A0km'));
    await tester.pump();
    expect(repo.retries, 1);

    repo.emit(_search(searchRadiusKm: 25, searchExhausted: false));
    await tester.pump();
    expect(find.text('Mencari ambulans terdekat...'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('Medical ID shows the patient card', (tester) async {
    await pumpHome(
      tester,
      medical: MedicalProfile(
        bloodType: 'O+',
        birthDate: DateTime(DateTime.now().year - 34, 1, 1),
        weightKg: 58,
        heightCm: 160,
        allergies: const ['Penisilin'],
        conditions: const ['Asma', 'Hipertensi'],
        emergencyContact: const EmergencyContact(
          name: 'Andi Pratama',
          relation: 'Suami',
          phone: '+62 812 9988 7766',
        ),
      ),
    );

    await tester.tap(find.text('Medical ID'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('O+'), findsOneWidget);
    expect(find.text('34 th'), findsOneWidget);
    expect(find.text('58 kg'), findsOneWidget);
    expect(find.text('160 cm'), findsOneWidget);
    expect(find.text('Penisilin'), findsOneWidget);
    expect(find.text('Hipertensi'), findsOneWidget);
    expect(find.text('Suami — Andi Pratama'), findsOneWidget);
    expect(find.text('+62 812 9988 7766'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('Profil shows emergency readiness', (tester) async {
    await pumpHome(tester, medical: const MedicalProfile(bloodType: 'O+'));

    await tester.tap(find.text('Profil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Kesiapan darurat'), findsOneWidget);
    expect(find.text('1 dari 4'), findsOneWidget);
    // The next missing item is offered first.
    expect(find.text('Tambah kontak darurat'), findsOneWidget);
    expect(find.text('Belum ada alamat tersimpan'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('Riwayat lists past requests', (tester) async {
    await pumpHome(
      tester,
      history: [
        EmergencyHistoryItem(
          id: 'req-0',
          code: 'CA-OLD001',
          status: 'completed',
          emergencyType: 'Henti Jantung',
          pickupAddress: 'Jl. Sudirman No. 21',
          requestedAt: DateTime(2026, 11, 3, 14, 5),
          hospitalName: 'RS Medika',
          plateNumber: 'B 1199 SGM',
        ),
      ],
    );

    await tester.tap(find.text('Riwayat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Henti Jantung · #CA-OLD001'), findsOneWidget);
    expect(find.text('3 Nov 2026 · 14:05'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);
    expect(find.text('RS Medika · B 1199 SGM'), findsOneWidget);

    await unmount(tester);
  });
}
