import 'dart:convert';

import 'package:cari_ambulan_app/core/location/location_service.dart';
import 'package:cari_ambulan_app/core/network/api_client.dart';
import 'package:cari_ambulan_app/features/auth/domain/auth_models.dart';
import 'package:cari_ambulan_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:cari_ambulan_app/features/emergency/data/api_emergency_repository.dart';
import 'package:cari_ambulan_app/features/emergency/data/emergency_repository.dart';
import 'package:cari_ambulan_app/features/emergency/domain/emergency_models.dart';
import 'package:cari_ambulan_app/features/user/data/address_repository.dart';
import 'package:cari_ambulan_app/features/user/data/medical_repository.dart';
import 'package:cari_ambulan_app/features/user/domain/medical_profile.dart';
import 'package:cari_ambulan_app/features/user/domain/saved_address.dart';
import 'package:cari_ambulan_app/features/user/presentation/pages/user_home_page.dart';
import 'package:cari_ambulan_app/features/user/presentation/pages/user_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _user = AuthUser(
  id: 'u-1',
  fullName: 'Siti Rahmawati',
  phone: '0812',
  roles: ['user'],
);

class _FakeAuth extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => _user;
}

class _Addresses implements AddressRepository {
  final saved = <SavedAddress>[
    const SavedAddress(
      id: 'a-1',
      label: 'Rumah',
      address: 'Jl. Kenanga 5, RT 02/RW 03',
      latitude: -6.25,
      longitude: 106.85,
    ),
  ];
  final calls = <String>[];

  @override
  Future<List<SavedAddress>> fetch() async => List.of(saved);

  @override
  Future<SavedAddress> add(SavedAddress address) async {
    calls.add('add ${address.label} ${address.latitude}');
    saved.insert(0, address);
    return address;
  }

  @override
  Future<void> remove(String id) async {
    calls.add('remove $id');
    saved.removeWhere((a) => a.id == id);
  }
}

class _Medical implements MedicalRepository {
  @override
  Future<MedicalProfile> fetch() async => const MedicalProfile();

  @override
  Future<MedicalProfile> save(MedicalProfile profile) async => profile;

  @override
  Future<bool> hasPendingSync() async => false;
}

/// Records where the ambulance was sent.
class _Emergency implements EmergencyRepository {
  EmergencyLocation? sentTo;

  @override
  Future<EmergencyRequestModel?> getCurrentRequest() async => null;

  @override
  Future<EmergencyRequestModel> createEmergencyRequest({
    required double latitude,
    required double longitude,
    required String address,
    bool isForSelf = true,
    String? emergencyType,
    String? severityLevel,
    String? notes,
  }) async {
    final pickup = EmergencyLocation(
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
    sentTo = pickup;
    return EmergencyRequestModel(
      id: 'req-1',
      requestCode: 'CA-1',
      status: EmergencyRequestStatus.searchingDriver,
      pickup: pickup,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// GPS that is either at [position] or unavailable.
class _Location extends LocationService {
  _Location(this.position);

  final Position? position;

  @override
  Future<Position?> getCurrentPosition() async => position;
}

Position _at(double latitude, double longitude) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime(2026),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

/// The SOS button pulses forever, so wait a fixed time instead of
/// pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  required _Addresses addresses,
  _Emergency? emergency,
  Position? gps,
}) async {
  tester.view.physicalSize = const Size(1800, 3600);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(_FakeAuth.new),
        addressRepositoryProvider.overrideWithValue(addresses),
        medicalRepositoryProvider.overrideWithValue(_Medical()),
        emergencyRepositoryProvider.overrideWithValue(
          emergency ?? _Emergency(),
        ),
        locationServiceProvider.overrideWithValue(_Location(gps)),
      ],
      child: MaterialApp(home: Scaffold(body: page)),
    ),
  );
  await _settle(tester);
}

void main() {
  test('uses GET, POST and DELETE me/addresses', () async {
    final calls = <String>[];
    final repo = ApiAddressRepository(
      ApiClient(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          calls.add('${request.method} ${request.url.path} ${request.body}');
          final data = request.method == 'GET'
              ? [
                  {
                    'id': 'a-1',
                    'label': 'Rumah',
                    'address': 'Jl. Kenanga 5',
                    'latitude': -6.25,
                    'longitude': 106.85,
                  },
                ]
              : {'id': 'a-2', 'label': 'Kantor', 'address': 'Jl. Thamrin'};
          return http.Response(
            jsonEncode({'data': data}),
            request.method == 'POST' ? 201 : 200,
          );
        }),
      ),
    );

    final list = await repo.fetch();
    expect(list.single.label, 'Rumah');
    expect(list.single.location.latitude, -6.25);

    final added = await repo.add(
      const SavedAddress(
        label: 'Kantor',
        address: 'Jl. Thamrin',
        latitude: -6.19,
        longitude: 106.82,
      ),
    );
    expect(added.id, 'a-2');
    await repo.remove('a-1');

    expect(calls, [
      'GET /api/v1/me/addresses ',
      'POST /api/v1/me/addresses '
          '{"label":"Kantor","address":"Jl. Thamrin",'
          '"latitude":-6.19,"longitude":106.82}',
      'DELETE /api/v1/me/addresses/a-1 ',
    ]);
  });

  testWidgets('SOS can send the ambulance to a saved address', (tester) async {
    final emergency = _Emergency();
    await _pump(
      tester,
      const UserHomePage(user: _user),
      addresses: _Addresses(),
      emergency: emergency,
    );

    await tester.tap(find.text('SOS'));
    await _settle(tester);
    expect(find.text('Kirim ambulans ke:'), findsOneWidget);

    await tester.tap(find.text('Rumah'));
    await _settle(tester);
    expect(find.text('Jl. Kenanga 5, RT 02/RW 03'), findsOneWidget);

    await tester.tap(find.text('PANGGIL SEKARANG (SOS)'));
    await _settle(tester);

    expect(emergency.sentTo?.address, 'Jl. Kenanga 5, RT 02/RW 03');
    expect(emergency.sentTo?.latitude, -6.25);
  });

  testWidgets('Profil lists, adds and deletes addresses', (tester) async {
    final addresses = _Addresses();
    await _pump(
      tester,
      UserProfilePage(onOpenMedicalId: () {}),
      addresses: addresses,
      gps: _at(-6.19, 106.82),
    );
    expect(find.text('Alamat tersimpan'), findsOneWidget);
    expect(find.text('Jl. Kenanga 5, RT 02/RW 03'), findsOneWidget);

    // Add the office from where the phone is now.
    await tester.tap(find.text('Tambah'));
    await _settle(tester);
    await tester.tap(find.text('Kantor'));
    await tester.enterText(find.byType(TextField).last, 'Jl. Thamrin 1');
    await tester.pump();
    await tester.tap(find.text('Simpan'));
    await _settle(tester);
    expect(addresses.calls, ['add Kantor -6.19']);
    expect(find.text('Jl. Thamrin 1'), findsOneWidget);

    // Delete home, after confirming.
    await tester.tap(find.text('Jl. Kenanga 5, RT 02/RW 03'));
    await _settle(tester);
    await tester.tap(find.text('Hapus'));
    await _settle(tester);
    expect(addresses.calls.last, 'remove a-1');
    expect(find.text('Jl. Kenanga 5, RT 02/RW 03'), findsNothing);
  });

  testWidgets('without GPS nothing is saved', (tester) async {
    final addresses = _Addresses();
    await _pump(
      tester,
      UserProfilePage(onOpenMedicalId: () {}),
      addresses: addresses,
    );

    await tester.tap(find.text('Tambah'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Jl. Melati 2');
    await tester.pump();
    await tester.tap(find.text('Simpan'));
    await _settle(tester);

    expect(find.textContaining('Lokasi GPS tidak tersedia'), findsOneWidget);
    expect(addresses.calls, isEmpty);
  });
}
