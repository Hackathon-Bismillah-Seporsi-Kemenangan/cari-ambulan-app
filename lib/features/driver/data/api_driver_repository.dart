import 'dart:async';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../../core/location/location_service.dart';
import '../../../core/network/api_client.dart';
import '../domain/driver_models.dart';
import 'driver_repository.dart';

/// [DriverRepository] backed by the CariAmbulan Laravel API (`/api/v1/driver`).
///
/// Incoming calls are polled while the driver is online; swap in a push
/// channel (FCM / Reverb) later without changing the UI.
class ApiDriverRepository implements DriverRepository {
  ApiDriverRepository(this._client, {LocationService? location})
    : _location = location ?? LocationService();

  final ApiClient _client;
  final LocationService _location;

  // The server answers these from a warm php-fpm pool without dispatching work,
  // so a 1 s poll is cheap and makes offers and calls feel live.
  static const pollInterval = Duration(seconds: 1);

  /// Last known availability; polling only runs while online.
  DriverAvailability _availability = DriverAvailability.offline;

  /// Shares one `GET /driver/profile` between the profile, stats and
  /// availability lookups the home screen makes together.
  Future<Map<String, dynamic>>? _profileRequest;

  Future<Map<String, dynamic>> _profile() => _profileRequest ??= _client
      .get('driver/profile')
      .then((json) => json!)
      .whenComplete(() => _profileRequest = null);

  @override
  Future<DriverProfile> fetchProfile() async {
    final data = (await _profile())['data'] as Map<String, dynamic>;
    final vehicle = data['vehicle'] as Map<String, dynamic>?;
    final hospital = data['hospital'] as Map<String, dynamic>?;
    return DriverProfile(
      id: data['id'] as String,
      name: data['name'] as String,
      vehiclePlate: vehicle?['plate_number'] as String? ?? '–',
      vehicleType: vehicle?['vehicle_type'] as String? ?? 'Ambulans',
      phone: data['phone'] as String?,
      licenseNumber: data['license_number'] as String?,
      hospitalName: hospital?['name'] as String?,
    );
  }

  @override
  Future<DriverTodayStats> fetchTodayStats() async {
    final json = await _profile();
    final today = json['today'] as Map<String, dynamic>;
    final total = json['total'] as Map<String, dynamic>?;
    return DriverTodayStats(
      completedTrips: today['completed_trips'] as int,
      totalCompletedTrips: total?['completed_trips'] as int?,
    );
  }

  @override
  Future<List<DriverTripHistoryItem>> fetchTripHistory() async {
    try {
      final json = await _client.get('driver/trips');
      return [
        for (final item in json?['data'] as List? ?? const [])
          DriverTripHistoryItem.fromJson(item as Map<String, dynamic>),
      ];
    } on ApiException {
      return const [];
    }
  }

  @override
  Future<({String fullName, String? phone})> updateAccount({
    required String fullName,
    required String phone,
  }) async {
    final json = await _client.put('me', {
      'full_name': fullName,
      'phone': phone,
    });
    final data = json!['data'] as Map<String, dynamic>;
    return (
      fullName: data['full_name'] as String,
      phone: data['phone'] as String?,
    );
  }

  @override
  Future<DriverAvailability> fetchAvailability() async {
    final data = (await _profile())['data'] as Map<String, dynamic>;
    return _availability = _parseAvailability(data['availability_status']);
  }

  @override
  Future<void> setAvailability(
    DriverAvailability availability,
    LatLng location,
  ) async {
    await _client.put('driver/availability', {
      'status': availability.name,
      'latitude': location.latitude,
      'longitude': location.longitude,
    });
    _availability = availability;
  }

  @override
  Future<NearbyHospital?> fetchNearestHospital(LatLng from) async {
    final json = await _client.get(
      'hospitals/nearest',
      query: {'latitude': '${from.latitude}', 'longitude': '${from.longitude}'},
    );
    final data = json?['data'] as Map<String, dynamic>?;
    return data == null ? null : _hospital(data, from: from);
  }

  @override
  Stream<LatLng> watchLocation() => _location.watch();

  @override
  Future<void> reportLocation(LatLng location) => _client.post(
    'driver/location',
    {'latitude': location.latitude, 'longitude': location.longitude},
  );

  @override
  Future<ActiveTrip?> fetchActiveTrip() async {
    final json = await _client.get('driver/trip');
    final data = json?['data'] as Map<String, dynamic>?;
    // The server keeps returning a trip for a while after the patient
    // cancelled it; that order is over, not one to resume.
    if (data == null || _isOver(data['status'])) return null;
    _availability = DriverAvailability.busy;
    return _trip(data);
  }

  @override
  Future<RemoteTripStatus> checkTrip(String requestId) async {
    final json = await _client.get('driver/trip');
    final data = json?['data'] as Map<String, dynamic>?;
    if (data == null || '${data['id']}' != requestId) {
      return RemoteTripStatus.ended;
    }
    return switch (data['status']) {
      'cancelled' => RemoteTripStatus.cancelled,
      'completed' => RemoteTripStatus.ended,
      _ => RemoteTripStatus.active,
    };
  }

  static bool _isOver(Object? status) =>
      status == 'cancelled' || status == 'completed';

  @override
  Stream<EmergencyRequest> watchIncomingRequests() {
    late final StreamController<EmergencyRequest> controller;
    Timer? timer;
    String? lastOfferId;
    var isPolling = false;

    Future<void> poll() async {
      if (isPolling || _availability != DriverAvailability.online) return;
      isPolling = true;
      try {
        final json = await _client.get('driver/offers/current');
        final offer = json?['data'] as Map<String, dynamic>?;
        if (offer == null) return;
        final offerId = '${offer['id']}';
        if (offerId == lastOfferId) return;
        lastOfferId = offerId;
        controller.add(_offer(offer));
      } on ApiException {
        // Transient network errors: try again on the next tick.
      } finally {
        isPolling = false;
      }
    }

    controller = StreamController<EmergencyRequest>.broadcast(
      onListen: () {
        poll();
        timer = Timer.periodic(pollInterval, (_) => poll());
      },
      onCancel: () => timer?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<void> acceptRequest(String requestId) async {
    await _client.post('driver/requests/$requestId/accept');
    _availability = DriverAvailability.busy;
  }

  @override
  Future<void> declineRequest(String requestId) =>
      _client.post('driver/requests/$requestId/decline');

  @override
  Future<void> markArrivedAtPatient(String requestId) =>
      _client.post('driver/requests/$requestId/arrive');

  @override
  Future<HospitalAssignment> startToHospital(
    String requestId,
    LatLng from,
  ) async {
    // The server picks the hospital nearest to the driver's last fix.
    await reportLocation(from);
    final json = await _client.post(
      'driver/requests/$requestId/start-to-hospital',
    );
    final data = json!['data'] as Map<String, dynamic>;
    return _assignment(data, from: from)!;
  }

  @override
  Future<void> completeHandover(String requestId) async {
    await _client.post('driver/requests/$requestId/complete');
    _availability = DriverAvailability.online;
  }

  @override
  Stream<TripCall?> watchTripCall() {
    late final StreamController<TripCall?> controller;
    Timer? timer;
    var isPolling = false;

    Future<void> poll() async {
      if (isPolling) return;
      isPolling = true;
      try {
        final json = await _client.get('driver/calls/current');
        final data = json?['data'] as Map<String, dynamic>?;
        controller.add(data == null ? null : _call(data));
      } on ApiException {
        // Transient network errors: try again on the next tick.
      } finally {
        isPolling = false;
      }
    }

    controller = StreamController<TripCall?>.broadcast(
      onListen: () {
        poll();
        timer = Timer.periodic(pollInterval, (_) => poll());
      },
      onCancel: () => timer?.cancel(),
    );
    return controller.stream;
  }

  // TODO: connect the voice audio (Agora / Twilio / WebRTC) when a call is
  // answered; these endpoints only track the call's state.
  @override
  Future<TripCall> answerCall(String callId) async {
    final json = await _client.post('driver/calls/$callId/answer');
    return _call(json!['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> declineCall(String callId) =>
      _client.post('driver/calls/$callId/decline');

  @override
  Future<void> endCall(String callId) =>
      _client.post('driver/calls/$callId/end');

  // --- JSON mapping -------------------------------------------------------

  TripCall _call(Map<String, dynamic> json) {
    final caller = json['caller'] as Map<String, dynamic>;
    final request = json['request'] as Map<String, dynamic>;
    return TripCall(
      id: json['id'] as String,
      status: json['status'] == 'answered'
          ? TripCallStatus.answered
          : TripCallStatus.ringing,
      callerName: caller['name'] as String,
      requestCode: request['code'] as String?,
      // By the server's clock, like the offer countdown.
      ringEndsAt: DateTime.now().add(
        Duration(seconds: json['ring_seconds_remaining'] as int? ?? 0),
      ),
      answeredAt: switch (json['talk_seconds']) {
        final int seconds => DateTime.now().subtract(
          Duration(seconds: seconds),
        ),
        _ => null,
      },
    );
  }

  DriverAvailability _parseAvailability(Object? value) =>
      DriverAvailability.values.firstWhere(
        (a) => a.name == value,
        orElse: () => DriverAvailability.offline,
      );

  NearbyHospital _hospital(Map<String, dynamic> json, {LatLng? from}) {
    final location = LatLng(
      (json['latitude'] as num).toDouble(),
      (json['longitude'] as num).toDouble(),
    );
    final distanceKm =
        (json['distance_km'] as num?)?.toDouble() ??
        (from == null
            ? 0.0
            : const Distance().as(LengthUnit.Meter, from, location) / 1000);
    return NearbyHospital(
      name: json['name'] as String,
      location: location,
      distanceKm: distanceKm,
    );
  }

  HospitalAssignment? _assignment(
    Map<String, dynamic> request, {
    LatLng? from,
  }) {
    final hospital = request['hospital'] as Map<String, dynamic>?;
    if (hospital == null) return null;
    return HospitalAssignment(
      hospital: _hospital(hospital, from: from),
      preparation: request['hospital_preparation'] as String? ?? '',
      entrance: hospital['ambulance_entrance'] as String?,
    );
  }

  /// An offered call from `GET /driver/offers/current`.
  EmergencyRequest _offer(Map<String, dynamic> offer) {
    final window = _time(
      offer['expires_at'],
    )!.difference(_time(offer['offered_at'])!);
    // Count down by the server's clock (seconds left right now), so a phone
    // clock that is off or a late poll can't make "Terima" fail at 0.
    final remaining = Duration(
      seconds: (offer['seconds_remaining'] as int?) ?? window.inSeconds,
    );
    final expiresAt = DateTime.now().add(remaining);
    final nearest = offer['nearest_hospital'] as Map<String, dynamic>?;

    return _request(
      offer['request'] as Map<String, dynamic>,
      distanceKm: (offer['distance_km'] as num).toDouble(),
      etaMinutes: offer['eta_minutes'] as int,
      nearestHospitalName: nearest?['name'] as String?,
      offeredAt: expiresAt.subtract(window),
      expiresAt: expiresAt,
    );
  }

  /// The trip in progress, from `GET /driver/trip`.
  ActiveTrip _trip(Map<String, dynamic> json) {
    final acceptedAt = _time(json['accepted_at']) ?? DateTime.now();
    return ActiveTrip(
      request: _request(json, offeredAt: acceptedAt, expiresAt: acceptedAt),
      acceptedAt: acceptedAt,
      stage: switch (json['status']) {
        'arrive_at_pickup' => TripStage.atPatient,
        'en_route_to_hospital' => TripStage.toHospital,
        _ => TripStage.toPatient,
      },
      arrivedAt: _time(json['arrived_at_pickup_at']),
      departedToHospitalAt: _time(json['picked_up_at']),
      hospital: _assignment(json),
    );
  }

  EmergencyRequest _request(
    Map<String, dynamic> json, {
    required DateTime offeredAt,
    required DateTime expiresAt,
    double? distanceKm,
    int? etaMinutes,
    String? nearestHospitalName,
  }) {
    final pickup = json['pickup'] as Map<String, dynamic>;
    final reporter = json['reporter'] as Map<String, dynamic>;
    final medical = json['medical'] as Map<String, dynamic>?;
    final hospital = json['hospital'] as Map<String, dynamic>?;
    final km = distanceKm ?? 0;
    final bloodType = medical?['blood_type'] as String?;

    return EmergencyRequest(
      id: json['id'] as String,
      code: json['code'] as String?,
      reporterName: reporter['name'] as String,
      reporterPhone: reporter['phone'] as String,
      condition: json['emergency_type'] as String,
      patientCount: 1,
      pickupAddress: pickup['address'] as String,
      pickupLocation: LatLng(
        (pickup['latitude'] as num).toDouble(),
        (pickup['longitude'] as num).toDouble(),
      ),
      distanceKm: km,
      // ~25 km/h average with sirens in city traffic.
      etaMinutes: etaMinutes ?? math.max(1, (km / 25 * 60).ceil()),
      nearestHospitalName:
          nearestHospitalName ?? hospital?['name'] as String? ?? '–',
      bloodType: bloodType == 'unknown' ? null : bloodType,
      allergy: _allergies(medical?['allergies']),
      note: json['patient_notes'] as String?,
      isHighPriority: json['is_high_priority'] as bool? ?? false,
      requestedAt: _time(json['request_at']),
      offeredAt: offeredAt,
      expiresAt: expiresAt,
    );
  }

  /// "Penisilin, Seafood": the server sends a list (older servers, text).
  String? _allergies(Object? value) {
    final text = value is List ? value.join(', ') : value as String?;
    return text == null || text.isEmpty ? null : text;
  }

  DateTime? _time(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();
}
