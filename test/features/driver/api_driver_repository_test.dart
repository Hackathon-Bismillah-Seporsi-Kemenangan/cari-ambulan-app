import 'dart:convert';

import 'package:cari_ambulan_app/core/network/api_client.dart';
import 'package:cari_ambulan_app/features/driver/data/api_driver_repository.dart';
import 'package:cari_ambulan_app/features/emergency/domain/emergency_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// An emergency as the server's `EmergencyRequestResource` sends it.
Map<String, dynamic> _request(String status) => {
  'id': 'req-9',
  'code': 'CA-B3HOZH',
  'status': status,
  'emergency_type': 'Jantung',
  'severity_level': 'high',
  'is_for_self': true,
  'patient_notes': 'Nyeri dada',
  'pickup': {
    'latitude': -6.2,
    'longitude': 106.8,
    'address': 'Jl. Sudirman No. 10',
  },
  'reporter': {'name': 'Budi', 'phone': '08123'},
};

void main() {
  late List<String> calls;

  ApiDriverRepository repoReturning(Object? Function(http.Request) body) {
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      final json = body(request);
      return json == null
          ? http.Response('', 204)
          : http.Response(jsonEncode(json), 200);
    });
    return ApiDriverRepository(
      ApiClient(client: client, baseUrl: 'http://test'),
    );
  }

  setUp(() => calls = []);

  test('parses the current offer from the server shape', () async {
    final repo = repoReturning(
      (_) => {
        'data': {
          'id': 42,
          'status': 'pending',
          'distance_km': 2,
          'eta_minutes': 5,
          'offered_at': '2026-11-09T10:00:00+07:00',
          'expires_at': '2026-11-09T10:00:30+07:00',
          'seconds_remaining': 21,
          'request': _request('searching_driver'),
        },
      },
    );

    final offer = (await repo.getCurrentOffer())!;

    expect(calls, ['GET /api/v1/driver/offers/current']);
    expect(offer.id, 42);
    expect(offer.emergencyRequestId, 'req-9');
    expect(offer.requestCode, 'CA-B3HOZH');
    expect(offer.distanceKm, 2.0);
    expect(offer.secondsRemaining, 21);
    expect(offer.emergencyType, 'Jantung');
    expect(offer.pickupAddress, 'Jl. Sudirman No. 10');
    expect(offer.patientName, 'Budi');
    expect(offer.patientPhone, '08123');
  });

  test('accepts and declines by emergency request id', () async {
    final repo = repoReturning(
      (r) => r.url.path.endsWith('accept')
          ? {'data': _request('en_route_to_pickup')}
          : null,
    );

    final trip = await repo.acceptRequest('req-9');
    await repo.declineRequest('req-9');

    expect(calls, [
      'POST /api/v1/driver/requests/req-9/accept',
      'POST /api/v1/driver/requests/req-9/decline',
    ]);
    expect(trip.status, EmergencyRequestStatus.enRouteToPickup);
    expect(trip.requestCode, 'CA-B3HOZH');
  });

  test('loads the trip and moves it through each stage', () async {
    final statusFor = {
      'trip': 'en_route_to_pickup',
      'arrive': 'arrive_at_pickup',
      'start-to-hospital': 'en_route_to_hospital',
      'complete': 'completed',
    };
    final repo = repoReturning(
      (r) => {'data': _request(statusFor[r.url.pathSegments.last]!)},
    );

    final trip = await repo.getActiveTrip();
    final arrived = await repo.markArrived('req-9');
    final toHospital = await repo.startToHospital('req-9');
    final done = await repo.completeTrip('req-9');

    expect(calls, [
      'GET /api/v1/driver/trip',
      'POST /api/v1/driver/requests/req-9/arrive',
      'POST /api/v1/driver/requests/req-9/start-to-hospital',
      'POST /api/v1/driver/requests/req-9/complete',
    ]);
    expect(trip!.status, EmergencyRequestStatus.enRouteToPickup);
    expect(arrived.status, EmergencyRequestStatus.arriveAtPickup);
    expect(toHospital.status, EmergencyRequestStatus.enRouteToHospital);
    expect(done.status, EmergencyRequestStatus.completed);
  });

  test('reads today\'s completed trips beside the profile', () async {
    final repo = repoReturning(
      (_) => {
        'data': {
          'id': 'drv-1',
          'name': 'Budi',
          'availability_status': 'online',
        },
        'today': {'completed_trips': 3},
      },
    );

    final profile = await repo.fetchProfile();

    expect(profile.completedTripsToday, 3);
    expect(profile.isOnline, isTrue);
  });

  test('parses the trip history', () async {
    final repo = repoReturning(
      (_) => {
        'data': [
          {
            'id': 12,
            'code': 'CA-DONE1',
            'status': 'completed',
            'emergency_type': 'Jantung',
            'pickup_address': 'Jl. Sudirman No. 10',
            'request_at': '2026-11-09T10:00:00+07:00',
            'patient_name': 'Budi',
            'hospital_name': 'RSUD Tarakan',
            'completed_at': '2026-11-09T10:40:00+07:00',
          },
          {
            'id': 13,
            'code': 'CA-STOP1',
            'status': 'cancelled',
            'pickup_address': 'Jl. Thamrin',
            'request_at': '2026-11-09T11:00:00+07:00',
            'cancel_reason': 'Sudah diantar keluarga',
          },
        ],
      },
    );

    final trips = await repo.fetchTripHistory();

    expect(calls, ['GET /api/v1/driver/trips']);
    expect(trips.map((t) => t.id), ['12', '13']);
    expect(trips.first.isCompleted, isTrue);
    expect(trips.first.hospitalName, 'RSUD Tarakan');
    expect(trips.last.isCancelled, isTrue);
    expect(trips.last.emergencyType, 'Darurat');
    expect(trips.last.cancelReason, 'Sudah diantar keluarga');
  });

  test('updates the account with PUT me', () async {
    late Map<String, dynamic> sent;
    final repo = repoReturning((request) {
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return {
        'data': {'id': 'u-1', 'full_name': 'Budi S.', 'phone': '0899'},
      };
    });

    final updated = await repo.updateAccount(
      fullName: 'Budi S.',
      phone: '0899',
    );

    expect(calls, ['PUT /api/v1/me']);
    expect(sent, {'full_name': 'Budi S.', 'phone': '0899'});
    expect(updated.fullName, 'Budi S.');
    expect(updated.phone, '0899');
  });
}
