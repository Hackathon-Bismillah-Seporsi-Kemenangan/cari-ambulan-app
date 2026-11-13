import 'dart:convert';

import 'package:cari_ambulan/core/network/api_client.dart';
import 'package:cari_ambulan/features/driver/data/api_driver_repository.dart';
import 'package:cari_ambulan/features/driver/domain/driver_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

/// Shape of `EmergencyRequestResource` from the Laravel API.
Map<String, dynamic> requestJson({
  String status = 'searching_driver',
  Map<String, dynamic>? hospital,
}) => {
  'id': 'req-1',
  'code': 'CA-B3HOZH',
  'status': status,
  'emergency_type': 'Henti Jantung',
  'severity_level': 'high',
  'is_high_priority': true,
  'is_for_self': true,
  'patient_notes': 'Kami tunggu di lobby.',
  'pickup': {
    'latitude': -6.2198,
    'longitude': 106.8152,
    'address': 'Jl. Sudirman No. 21',
  },
  'reporter': {'name': 'Siti Rahmawati', 'phone': '081234567890'},
  'medical': {
    'blood_type': 'O',
    // Lists since the Medical ID update.
    'allergies': ['Penisilin', 'Seafood'],
    'medical_conditions': <String>[],
  },
  'hospital': hospital,
  'hospital_preparation': hospital == null
      ? null
      : 'IGD menyiapkan tim jantung.',
  'request_at': '2026-11-02T16:46:45+00:00',
  'accepted_at': status == 'searching_driver'
      ? null
      : '2026-11-02T16:47:00+00:00',
  'arrived_at_pickup_at': null,
  'picked_up_at': hospital == null ? null : '2026-11-02T16:55:00+00:00',
  'completed_at': null,
};

const hospitalJson = {
  'id': 'h-1',
  'name': 'RS Medika',
  'latitude': -6.2005,
  'longitude': 106.8160,
  'ambulance_entrance': 'Gerbang B',
};

(ApiDriverRepository, List<http.Request>) repoWith(
  http.Response Function(http.Request request) handler,
) {
  final requests = <http.Request>[];
  final client = MockClient((request) async {
    requests.add(request);
    return handler(request);
  });
  final api = ApiClient(client: client, baseUrl: 'http://api.test')
    ..token = 'secret';
  return (ApiDriverRepository(api), requests);
}

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('maps an offered call from the offers endpoint', () async {
    final (repo, requests) = repoWith((request) {
      if (request.url.path.endsWith('availability')) return json({'data': {}});
      return json({
        'data': {
          'id': 7,
          'status': 'offered',
          'distance_km': 1.45,
          'eta_minutes': 4,
          'offered_at': '2026-11-02T16:46:45+00:00',
          'expires_at': '2026-11-02T16:47:15+00:00',
          'seconds_remaining': 18,
          'nearest_hospital': hospitalJson,
          'request': requestJson(),
        },
      });
    });
    await repo.setAvailability(
      DriverAvailability.online,
      const LatLng(-6.2, 106.8),
    );

    final request = await repo.watchIncomingRequests().first;

    expect(request.id, 'req-1');
    expect(request.code, 'CA-B3HOZH');
    expect(request.condition, 'Henti Jantung');
    expect(request.reporterName, 'Siti Rahmawati');
    expect(request.bloodType, 'O');
    expect(request.allergy, 'Penisilin, Seafood');
    expect(request.distanceKm, 1.45);
    expect(request.etaMinutes, 4);
    expect(request.nearestHospitalName, 'RS Medika');
    expect(request.isHighPriority, isTrue);
    expect(request.offerWindow, const Duration(seconds: 30));
    expect(
      request.expiresAt.difference(DateTime.now()).inSeconds,
      inInclusiveRange(17, 18),
      reason: 'counts down by the server clock',
    );
    expect(
      requests.last.headers['Authorization'],
      'Bearer secret',
      reason: 'sends the Sanctum token',
    );
  });

  test('does not poll for calls while offline', () async {
    final (repo, requests) = repoWith((_) => json({'data': null}));

    final subscription = repo.watchIncomingRequests().listen((_) {});
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(requests, isEmpty);
  });

  test('resumes a trip on its way to the hospital', () async {
    final (repo, _) = repoWith(
      (_) => json({
        'data': requestJson(
          status: 'en_route_to_hospital',
          hospital: hospitalJson,
        ),
      }),
    );

    final trip = await repo.fetchActiveTrip();

    expect(trip!.stage, TripStage.toHospital);
    expect(trip.hospital!.hospital.name, 'RS Medika');
    expect(trip.hospital!.preparation, 'IGD menyiapkan tim jantung.');
    expect(trip.hospital!.entrance, 'Gerbang B');
    expect(trip.departedToHospitalAt, isNotNull);
  });

  test('does not resume a trip the patient cancelled', () async {
    final (repo, _) = repoWith(
      (_) => json({'data': requestJson(status: 'cancelled')}),
    );

    expect(await repo.fetchActiveTrip(), isNull);
  });

  test('tells whether the open trip is still going', () async {
    var status = 'en_route_to_pickup';
    final (repo, _) = repoWith(
      (_) => json({'data': requestJson(status: status)}),
    );
    final id = '${requestJson(status: status)['id']}';

    expect(await repo.checkTrip(id), RemoteTripStatus.active);
    status = 'cancelled';
    expect(await repo.checkTrip(id), RemoteTripStatus.cancelled);
    status = 'completed';
    expect(await repo.checkTrip(id), RemoteTripStatus.ended);
    expect(await repo.checkTrip('another-order'), RemoteTripStatus.ended);
  });

  test('surfaces the server message when an order was taken', () async {
    final (repo, _) = repoWith(
      (_) => json({
        'message': 'Order sudah diambil driver lain atau dibatalkan.',
      }, 409),
    );

    expect(
      repo.acceptRequest('req-1'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.isConflict, 'isConflict', isTrue)
            .having(
              (e) => e.message,
              'message',
              'Order sudah diambil driver lain atau dibatalkan.',
            ),
      ),
    );
  });

  test('uses the first validation error as the message', () async {
    final (repo, _) = repoWith(
      (_) => json({
        'message': 'The given data was invalid.',
        'errors': {
          'latitude': ['The latitude field is required when status is online.'],
        },
      }, 422),
    );

    expect(
      repo.reportLocation(const LatLng(0, 0)),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'The latitude field is required when status is online.',
        ),
      ),
    );
  });

  test('maps the reporter call and answers by the server clock', () async {
    final (repo, requests) = repoWith(
      (_) => json({
        'data': {
          'id': 'call-1',
          'status': 'answered',
          'caller': {'name': 'Siti Rahmawati', 'phone': '081234567890'},
          'request': {'id': 'req-1', 'code': 'CA-B3HOZH'},
          // Far from the phone's clock: only talk_seconds is trusted.
          'rang_at': '2020-01-01T00:00:00+00:00',
          'answered_at': '2020-01-01T00:00:05+00:00',
          'ended_at': null,
          'ring_seconds_remaining': 0,
          'talk_seconds': 42,
        },
      }),
    );

    final call = await repo.answerCall('call-1');

    expect(requests.single.url.path, '/api/v1/driver/calls/call-1/answer');
    expect(call.status, TripCallStatus.answered);
    expect(call.callerName, 'Siti Rahmawati');
    expect(call.requestCode, 'CA-B3HOZH');
    final talk = DateTime.now().difference(call.answeredAt!).inSeconds;
    expect(talk, inInclusiveRange(41, 43));
  });
}
