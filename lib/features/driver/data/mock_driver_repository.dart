import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../domain/driver_models.dart';
import 'driver_repository.dart';

/// Fake backend for tests and offline demos.
class MockDriverRepository implements DriverRepository {
  static const _latency = Duration(milliseconds: 600);

  // Around Universitas Jember, inside the offline map.
  static const _start = LatLng(-8.1724, 113.7008);

  /// How long after going online the fake emergency call arrives.
  static const incomingCallDelay = Duration(seconds: 5);

  DriverAvailability _availability = DriverAvailability.offline;
  int _completedTrips = 4;
  final _requests = StreamController<EmergencyRequest>.broadcast();
  Timer? _requestTimer;

  @override
  Future<DriverProfile> fetchProfile() async {
    await Future<void>.delayed(_latency);
    return const DriverProfile(
      id: 'mock-driver-1',
      name: 'Budi Santoso',
      vehiclePlate: 'B 1199 SGM',
      vehicleType: 'Ambulans ALS',
      phone: '081200001199',
      licenseNumber: 'SIM-31750001',
      hospitalName: 'RSUD Dr. Soebandi',
    );
  }

  @override
  Future<DriverTodayStats> fetchTodayStats() async {
    await Future<void>.delayed(_latency);
    return DriverTodayStats(
      completedTrips: _completedTrips,
      totalCompletedTrips: _completedTrips + 120,
      rating: 4.9,
    );
  }

  @override
  Future<List<DriverTripHistoryItem>> fetchTripHistory() async {
    await Future<void>.delayed(_latency);
    final now = DateTime.now();
    return [
      DriverTripHistoryItem(
        id: 'mock-trip-2',
        code: 'CA-MOCK02',
        status: 'cancelled',
        emergencyType: 'Sesak Nafas',
        pickupAddress: 'Jl. Kalimantan No. 37, Jember',
        requestedAt: now.subtract(const Duration(hours: 2)),
        patientName: 'Siti Rahmawati',
        cancelledAt: now.subtract(const Duration(hours: 2, minutes: -6)),
        cancelReason: 'Pasien sudah dibawa keluarga',
      ),
      DriverTripHistoryItem(
        id: 'mock-trip-1',
        code: 'CA-MOCK01',
        status: 'completed',
        emergencyType: 'Kecelakaan',
        pickupAddress: 'Jl. Jawa No. 12, Jember',
        requestedAt: now.subtract(const Duration(days: 1)),
        patientName: 'Andi Pratama',
        hospitalName: 'RSUD Dr. Soebandi',
        completedAt: now.subtract(const Duration(hours: 23)),
      ),
    ];
  }

  @override
  Future<({String fullName, String? phone})> updateAccount({
    required String fullName,
    required String phone,
  }) async {
    await Future<void>.delayed(_latency);
    return (fullName: fullName, phone: phone);
  }

  @override
  Future<DriverAvailability> fetchAvailability() async {
    await Future<void>.delayed(_latency);
    return _availability;
  }

  @override
  Future<void> setAvailability(
    DriverAvailability availability,
    LatLng location,
  ) async {
    await Future<void>.delayed(_latency);
    _availability = availability;

    _requestTimer?.cancel();
    if (availability == DriverAvailability.online) {
      _scheduleNextCall(incomingCallDelay);
    }
  }

  @override
  Future<NearbyHospital?> fetchNearestHospital(LatLng from) async {
    await Future<void>.delayed(_latency);
    const location = LatLng(-8.1641, 113.6946);
    final km = const Distance().as(LengthUnit.Meter, from, location) / 1000;
    return NearbyHospital(
      name: 'RS Medika',
      location: location,
      distanceKm: km,
    );
  }

  @override
  Stream<LatLng> watchLocation() async* {
    yield _start;
  }

  @override
  Future<void> reportLocation(LatLng location) async {}

  @override
  Future<ActiveTrip?> fetchActiveTrip() async => null;

  @override
  Future<RemoteTripStatus> checkTrip(String requestId) async =>
      RemoteTripStatus.active;

  @override
  Stream<EmergencyRequest> watchIncomingRequests() => _requests.stream;

  @override
  Future<void> acceptRequest(String requestId) async {
    await Future<void>.delayed(_latency);
    _availability = DriverAvailability.busy;
  }

  @override
  Future<void> markArrivedAtPatient(String requestId) async {
    await Future<void>.delayed(_latency);
  }

  @override
  Future<HospitalAssignment> startToHospital(
    String requestId,
    LatLng from,
  ) async {
    await Future<void>.delayed(_latency);
    final hospital = await fetchNearestHospital(from);
    return HospitalAssignment(
      hospital: hospital!,
      preparation: 'IGD menyiapkan tim jantung.',
      entrance: 'Gerbang B',
    );
  }

  @override
  Future<void> completeHandover(String requestId) async {
    await Future<void>.delayed(_latency);
    _completedTrips++;
    _availability = DriverAvailability.online;
    _scheduleNextCall(incomingCallDelay * 2);
  }

  @override
  Future<void> declineRequest(String requestId) async {
    await Future<void>.delayed(_latency);
    // Offer another call later so the flow can be tried again.
    if (_availability == DriverAvailability.online) {
      _scheduleNextCall(incomingCallDelay * 2);
    }
  }

  final _tripCalls = StreamController<TripCall?>.broadcast();

  /// Rings the driver as the reporter of the active order (demos and tests).
  TripCall ringFromReporter() {
    final call = TripCall(
      id: 'mock-call-${DateTime.now().millisecondsSinceEpoch}',
      status: TripCallStatus.ringing,
      callerName: 'Siti Rahmawati',
      requestCode: 'SGM-0421',
      ringEndsAt: DateTime.now().add(const Duration(seconds: 30)),
    );
    _tripCalls.add(call);
    return call;
  }

  @override
  Stream<TripCall?> watchTripCall() => _tripCalls.stream;

  @override
  Future<TripCall> answerCall(String callId) async {
    await Future<void>.delayed(_latency);
    return TripCall(
      id: callId,
      status: TripCallStatus.answered,
      callerName: 'Siti Rahmawati',
      requestCode: 'SGM-0421',
      ringEndsAt: DateTime.now(),
      answeredAt: DateTime.now(),
    );
  }

  @override
  Future<void> declineCall(String callId) async {
    await Future<void>.delayed(_latency);
  }

  @override
  Future<void> endCall(String callId) async {
    await Future<void>.delayed(_latency);
  }

  void _scheduleNextCall(Duration delay) {
    _requestTimer?.cancel();
    _requestTimer = Timer(delay, () => _requests.add(_fakeRequest(_start)));
  }

  EmergencyRequest _fakeRequest(LatLng driver) {
    const pickup = LatLng(-8.1881, 113.6911);
    final km = const Distance().as(LengthUnit.Meter, driver, pickup) / 1000;
    final now = DateTime.now();
    return EmergencyRequest(
      id: 'mock-order-${now.millisecondsSinceEpoch}',
      reporterName: 'Siti Rahmawati',
      reporterPhone: '+6281234567890',
      isHighPriority: true,
      condition: 'Jantung',
      symptom: 'Nyeri dada',
      patientCount: 1,
      pickupAddress: 'Jl. Sudirman No. 21, Jakarta Pusat',
      pickupDetail: 'Lobby Wisma 46, lantai dasar',
      pickupLocation: pickup,
      distanceKm: km,
      // ~25 km/h average with sirens in city traffic.
      etaMinutes: (km / 25 * 60).ceil(),
      nearestHospitalName: 'RS Medika',
      bloodType: 'O+',
      allergy: 'Alergi penisilin',
      note:
          'Ibu saya sesak dan nyeri dada sejak 10 menit lalu. '
          'Kami tunggu di lobby...',
      requestedAt: now.subtract(const Duration(minutes: 1)),
      offeredAt: now,
      expiresAt: now.add(const Duration(seconds: 30)),
    );
  }
}
