import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/app_log.dart';
import '../../../core/network/api_client.dart';
import '../../call/domain/call_models.dart';
import '../domain/user_models.dart';
import 'user_repository.dart';

class ApiUserRepository implements UserRepository {
  ApiUserRepository(this._client, {String? userId}) : _userId = userId;

  final ApiClient _client;

  /// Keys the copies kept on the phone, so accounts don't share them.
  final String? _userId;

  // The phone's own geocoder: free, no API key.
  final _geocoding = Geocoding(locale: const Locale('id', 'ID'));

  @override
  Future<NearestAmbulance?> fetchNearestAmbulance(LatLng from) async {
    final json = await _client.get(
      'ambulances/nearest',
      query: {'latitude': '${from.latitude}', 'longitude': '${from.longitude}'},
    );
    final data = json?['data'] as Map<String, dynamic>?;
    if (data == null) return null;
    return NearestAmbulance(
      location: LatLng(
        (data['latitude'] as num).toDouble(),
        (data['longitude'] as num).toDouble(),
      ),
      distanceKm: (data['distance_km'] as num).toDouble(),
      etaMinutes: data['eta_minutes'] as int,
    );
  }

  @override
  Future<String?> addressOf(LatLng point) async {
    final places = await _geocoding.placemarkFromCoordinates(
      point.latitude,
      point.longitude,
    );
    if (places.isEmpty) return null;
    final place = places.first;
    final street = place.thoroughfare;
    if (street != null && street.isNotEmpty) {
      final number = place.subThoroughfare;
      if (number == null || number.isEmpty) return street;
      // Some geocoders already write "No.39".
      return number.toLowerCase().startsWith('no')
          ? '$street $number'
          : '$street No. $number';
    }
    return [
      place.street,
      place.subLocality,
      place.locality,
    ].firstWhere((s) => s != null && s.isNotEmpty, orElse: () => null);
  }

  @override
  Future<String?> nearestHospitalName(LatLng from) async {
    final json = await _client.get(
      'hospitals/nearest',
      query: {'latitude': '${from.latitude}', 'longitude': '${from.longitude}'},
    );
    return (json?['data'] as Map<String, dynamic>?)?['name'] as String?;
  }

  @override
  Future<EmergencySearch> createEmergency({
    required LatLng pickup,
    required String address,
    required bool forSelf,
    required EmergencyType type,
  }) async {
    final json = await _client.post('emergency-requests', {
      'emergency_type': type.apiValue,
      'severity_level': 'high',
      'is_for_self': forSelf,
      'pickup_latitude': pickup.latitude,
      'pickup_longitude': pickup.longitude,
      'pickup_address': address,
    });
    return _search(json!['data'] as Map<String, dynamic>);
  }

  @override
  Future<EmergencySearch?> fetchOpenEmergency() async {
    final json = await _client.get('emergency-requests/current');
    final data = json?['data'] as Map<String, dynamic>?;
    return data == null ? null : _search(data);
  }

  @override
  Stream<EmergencySearch> watchEmergency(String id) async* {
    while (true) {
      try {
        final json = await _client.get('emergency-requests/$id');
        yield _search(json!['data'] as Map<String, dynamic>);
      } on ApiException catch (e) {
        // A dropped poll must not end the search; the next tick retries.
        // A 4xx means the request is gone or not ours, so stop there.
        if (e.statusCode != null && e.statusCode! < 500) rethrow;
      }
      await Future<void>.delayed(_pollEvery);
    }
  }

  @override
  Stream<IncomingCall?> watchIncomingCall() async* {
    while (true) {
      try {
        final json = await _client.get('calls/incoming');
        final data = json?['data'] as Map<String, dynamic>?;
        yield data == null ? null : IncomingCall.fromJson(data);
      } on ApiException {
        // Offline for a moment; check again on the next tick.
      }
      await Future<void>.delayed(_pollEvery);
    }
  }

  @override
  Future<EmergencySearch> cancelEmergency(String id, {String? reason}) async {
    final json = await _client.post('emergency-requests/$id/cancel', {
      'reason': ?reason,
    });
    return _search(json!['data'] as Map<String, dynamic>);
  }

  @override
  Future<EmergencySearch> expandSearchRadius(String id, double radiusKm) async {
    final json = await _client.post('emergency-requests/$id/radius', {
      'radius_km': radiusKm,
    });
    return _search(json!['data'] as Map<String, dynamic>);
  }

  @override
  Future<EmergencySearch> retrySearch(String id) async {
    final json = await _client.post('emergency-requests/$id/retry');
    return _search(json!['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> callDriver(String requestId) =>
      _client.post('emergency-requests/$requestId/calls');

  @override
  Future<List<EmergencyHistoryItem>> fetchHistory() async {
    final json = await _client.get('emergency-requests');
    return [
      for (final item in (json?['data'] as List?) ?? const [])
        _historyItem(item as Map<String, dynamic>),
    ];
  }

  @override
  Future<Synced<MedicalProfile>> fetchMedicalProfile() async {
    try {
      final json = await _client.get('me/medical-profile');
      final data = json?['data'] as Map<String, dynamic>?;
      final profile = data == null
          ? MedicalProfile.empty
          : MedicalProfile.fromJson(data);
      await _saveLocal(_medicalKey, profile.toJson());
      return (value: profile, synced: true);
    } on ApiException catch (e) {
      AppLog.warn('Sync', 'Medical ID from the phone only', e);
      final local = await _readLocal(_medicalKey);
      return (
        value: local is Map<String, dynamic>
            ? MedicalProfile.fromJson(local)
            : MedicalProfile.empty,
        synced: false,
      );
    }
  }

  @override
  Future<bool> saveMedicalProfile(MedicalProfile profile) async {
    await _saveLocal(_medicalKey, profile.toJson());
    try {
      await _client.put('me/medical-profile', profile.toJson());
      return true;
    } on ApiException catch (e) {
      AppLog.warn('Sync', 'Medical ID kept on the phone', e);
      return false;
    }
  }

  @override
  Future<Synced<List<SavedAddress>>> fetchAddresses() async {
    try {
      final json = await _client.get('me/addresses');
      final addresses = [
        for (final a in (json?['data'] as List?) ?? const [])
          SavedAddress.fromJson(a as Map<String, dynamic>),
      ];
      await _saveLocal(_addressesKey, [for (final a in addresses) a.toJson()]);
      return (value: addresses, synced: true);
    } on ApiException catch (e) {
      AppLog.warn('Sync', 'Addresses from the phone only', e);
      return (value: await _localAddresses(), synced: false);
    }
  }

  @override
  Future<bool> addAddress(SavedAddress address) async {
    final saved = await _localAddresses();
    try {
      final json = await _client.post('me/addresses', address.toJson());
      final stored = SavedAddress.fromJson(
        json!['data'] as Map<String, dynamic>,
      );
      await _saveLocal(_addressesKey, [
        for (final a in [...saved, stored]) a.toJson(),
      ]);
      return true;
    } on ApiException catch (e) {
      AppLog.warn('Sync', 'Address kept on the phone', e);
      await _saveLocal(_addressesKey, [
        for (final a in [...saved, address]) a.toJson(),
      ]);
      return false;
    }
  }

  @override
  Future<({String fullName, String? phone})> updateProfile({
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

  String get _medicalKey => 'medical_profile_$_userId';
  String get _addressesKey => 'saved_addresses_$_userId';

  Future<List<SavedAddress>> _localAddresses() async {
    final local = await _readLocal(_addressesKey);
    return [
      if (local is List)
        for (final a in local) SavedAddress.fromJson(a as Map<String, dynamic>),
    ];
  }

  Future<Object?> _readLocal(String key) async {
    final text = (await SharedPreferences.getInstance()).getString(key);
    return text == null ? null : jsonDecode(text);
  }

  Future<void> _saveLocal(String key, Object value) async =>
      (await SharedPreferences.getInstance()).setString(key, jsonEncode(value));

  static const _pollEvery = Duration(seconds: 1);

  /// Reads both the search view (`show`, `current`, `cancel`) and the full
  /// request returned by `store`, which has no search fields.
  EmergencySearch _search(Map<String, dynamic> json) {
    final pickup = json['pickup'] as Map<String, dynamic>;
    final status = json['status'] as String;
    return EmergencySearch(
      id: json['id'] as String,
      code: json['code'] as String,
      status: switch (status) {
        'searching_driver' => EmergencySearchStatus.searching,
        'cancelled' => EmergencySearchStatus.cancelled,
        'completed' => EmergencySearchStatus.completed,
        _ => EmergencySearchStatus.found,
      },
      emergencyType: json['emergency_type'] as String,
      pickup: LatLng(
        (pickup['latitude'] as num).toDouble(),
        (pickup['longitude'] as num).toDouble(),
      ),
      pickupAddress: pickup['address'] as String,
      driversContacted: json['drivers_contacted'] as int? ?? 0,
      nearbyAmbulances: [
        for (final a in (json['nearby_ambulances'] as List?) ?? const [])
          LatLng(
            ((a as Map)['latitude'] as num).toDouble(),
            (a['longitude'] as num).toDouble(),
          ),
      ],
      stage: switch (status) {
        'arrive_at_pickup' => TripStage.arrived,
        'en_route_to_hospital' => TripStage.toHospital,
        _ => TripStage.toPickup,
      },
      trip: _trip(json),
      requestAt: DateTime.tryParse(json['request_at'] as String? ?? ''),
      searchRadiusKm: (json['search_radius_km'] as num?)?.toDouble(),
      radiusExpandsInSeconds: (json['radius_expands_in_seconds'] as num?)
          ?.toInt(),
      searchExhausted: json['search_exhausted'] as bool?,
    );
  }

  /// The `driver`, `ambulance`, `hospital` and `eta` objects, when the server
  /// sends any of them.
  TripInfo? _trip(Map<String, dynamic> json) {
    final driver = json['driver'] as Map<String, dynamic>?;
    final ambulance = json['ambulance'] as Map<String, dynamic>?;
    final hospital = json['hospital'] as Map<String, dynamic>?;
    final eta = json['eta'] as Map<String, dynamic>?;
    if (driver == null && ambulance == null && hospital == null) return null;

    final latitude = ambulance?['latitude'] ?? driver?['latitude'];
    final longitude = ambulance?['longitude'] ?? driver?['longitude'];
    final hospitalLatitude = hospital?['latitude'];
    final hospitalLongitude = hospital?['longitude'];
    return TripInfo(
      driverName: driver?['name'] as String?,
      driverPhone: driver?['phone'] as String?,
      driverPhotoUrl: driver?['photo_url'] as String?,
      driverRating: (driver?['rating'] as num?)?.toDouble(),
      driverTripCount: (driver?['trip_count'] as num?)?.toInt(),
      plateNumber: ambulance?['plate_number'] as String?,
      vehicleType: ambulance?['vehicle_type'] as String?,
      ambulanceLocation: latitude is num && longitude is num
          ? LatLng(latitude.toDouble(), longitude.toDouble())
          : null,
      locationAgeSeconds: (ambulance?['location_age_seconds'] as num?)?.toInt(),
      hospitalName: hospital?['name'] as String?,
      hospitalLocation: hospitalLatitude is num && hospitalLongitude is num
          ? LatLng(hospitalLatitude.toDouble(), hospitalLongitude.toDouble())
          : null,
      hospitalPreparation: json['hospital_preparation'] as String?,
      hospitalEntrance: hospital?['ambulance_entrance'] as String?,
      etaMinutes: (eta?['minutes'] as num?)?.toInt(),
      distanceKm: (eta?['distance_km'] as num?)?.toDouble(),
      shareUrl: json['share_url'] as String?,
    );
  }

  EmergencyHistoryItem _historyItem(
    Map<String, dynamic> json,
  ) => EmergencyHistoryItem(
    id: json['id'] as String,
    code: json['code'] as String,
    status: json['status'] as String,
    emergencyType: json['emergency_type'] as String,
    pickupAddress:
        (json['pickup'] as Map<String, dynamic>?)?['address'] as String? ?? '',
    requestedAt: DateTime.parse(json['request_at'] as String).toLocal(),
    hospitalName:
        (json['hospital'] as Map<String, dynamic>?)?['name'] as String?,
    plateNumber:
        (json['ambulance'] as Map<String, dynamic>?)?['plate_number']
            as String?,
    driverName: (json['driver'] as Map<String, dynamic>?)?['name'] as String?,
  );
}
