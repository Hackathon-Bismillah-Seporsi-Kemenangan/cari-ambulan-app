import 'dart:convert';

import 'package:cari_ambulan_app/core/network/api_client.dart';
import 'package:cari_ambulan_app/features/auth/domain/auth_models.dart';
import 'package:cari_ambulan_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:cari_ambulan_app/features/emergency/data/api_emergency_repository.dart';
import 'package:cari_ambulan_app/features/emergency/data/emergency_repository.dart';
import 'package:cari_ambulan_app/features/emergency/domain/emergency_models.dart';
import 'package:cari_ambulan_app/features/user/data/address_repository.dart';
import 'package:cari_ambulan_app/features/user/data/medical_repository.dart';
import 'package:cari_ambulan_app/features/user/data/user_repository.dart';
import 'package:cari_ambulan_app/features/user/domain/emergency_history_item.dart';
import 'package:cari_ambulan_app/features/user/domain/medical_profile.dart';
import 'package:cari_ambulan_app/features/user/domain/saved_address.dart';
import 'package:cari_ambulan_app/features/user/presentation/pages/user_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _user = AuthUser(
  id: 'u-1',
  fullName: 'Siti Rahmawati',
  phone: '0812',
  roles: ['user'],
);

/// Signed in as [_user]; edits and logout stay in memory.
class _FakeAuth extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => _user;

  @override
  Future<void> updateUser(AuthUser user) async => state = AsyncData(user);

  @override
  Future<void> logout() async => state = const AsyncData(null);
}

class _NoEmergency implements EmergencyRepository {
  @override
  Future<EmergencyRequestModel?> getCurrentRequest() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Medical implements MedicalRepository {
  @override
  Future<MedicalProfile> fetch() async => const MedicalProfile(bloodType: 'O+');

  @override
  Future<MedicalProfile> save(MedicalProfile profile) async => profile;

  @override
  Future<bool> hasPendingSync() async => false;
}

class _NoAddresses implements AddressRepository {
  @override
  Future<List<SavedAddress>> fetch() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeUserRepo implements UserRepository {
  final calls = <String>[];

  @override
  Future<List<EmergencyHistoryItem>> fetchHistory() async {
    calls.add('history');
    return [
      EmergencyHistoryItem(
        id: '1',
        code: 'CA-DONE1',
        status: 'completed',
        emergencyType: 'Henti Jantung',
        pickupAddress: 'Jl. Sudirman No. 10',
        requestedAt: DateTime(2026, 11, 9, 10, 5),
        hospitalName: 'RSUD Tarakan',
        plateNumber: 'B 1199 SGM',
      ),
      EmergencyHistoryItem(
        id: '2',
        code: 'CA-STOP1',
        status: 'cancelled',
        emergencyType: 'Kecelakaan',
        pickupAddress: 'Jl. Thamrin',
        requestedAt: DateTime(2026, 11, 8, 21),
        cancelReason: 'Salah lokasi',
      ),
    ];
  }

  @override
  Future<({String fullName, String? phone})> updateAccount({
    required String fullName,
    required String phone,
  }) async {
    calls.add('update $fullName $phone');
    return (fullName: fullName, phone: phone);
  }
}

/// The SOS button pulses forever, so wait a fixed time instead of
/// pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<_FakeUserRepo> _pumpShell(WidgetTester tester) async {
  // Wide enough for the test font, whose glyphs are all full squares.
  tester.view.physicalSize = const Size(1800, 3200);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  final repo = _FakeUserRepo();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(_FakeAuth.new),
        emergencyRepositoryProvider.overrideWithValue(_NoEmergency()),
        medicalRepositoryProvider.overrideWithValue(_Medical()),
        userRepositoryProvider.overrideWithValue(repo),
        addressRepositoryProvider.overrideWithValue(_NoAddresses()),
      ],
      child: const MaterialApp(home: UserShell(user: _user)),
    ),
  );
  await _settle(tester);
  return repo;
}

void main() {
  test('reads the history from GET emergency-requests', () async {
    final calls = <String>[];
    final repo = ApiUserRepository(
      ApiClient(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'req-1',
                  'code': 'CA-DONE1',
                  'status': 'completed',
                  'emergency_type': 'Henti Jantung',
                  'pickup_address': 'Jl. Sudirman No. 10',
                  'request_at': '2026-11-09T10:05:00+07:00',
                  'hospital_name': 'RSUD Tarakan',
                  'ambulance_plate': 'B 1199 SGM',
                  'driver_name': 'Budi',
                },
              ],
            }),
            200,
          );
        }),
      ),
    );

    final items = await repo.fetchHistory();

    expect(calls, ['GET /api/v1/emergency-requests']);
    expect(items.single.isCompleted, isTrue);
    expect(items.single.plateNumber, 'B 1199 SGM');
    expect(items.single.driverName, 'Budi');
  });

  testWidgets('Riwayat loads on first visit and lists requests', (
    tester,
  ) async {
    final repo = await _pumpShell(tester);
    expect(repo.calls, isEmpty);

    await tester.tap(find.text('Riwayat'));
    await _settle(tester);

    expect(repo.calls, ['history']);
    expect(find.text('Henti Jantung · #CA-DONE1'), findsOneWidget);
    expect(find.text('RSUD Tarakan · B 1199 SGM'), findsOneWidget);
    expect(find.text('Dibatalkan'), findsOneWidget);
    expect(find.text('Salah lokasi'), findsOneWidget);
  });

  testWidgets('Profil edits the name and logs out after confirming', (
    tester,
  ) async {
    final repo = await _pumpShell(tester);

    await tester.tap(find.text('Profil'));
    await _settle(tester);

    expect(find.text('Kesiapan darurat'), findsOneWidget);
    // Blood type filled in; the contact is the next step.
    expect(find.text('Tambah kontak darurat'), findsOneWidget);

    await tester.tap(find.byTooltip('Ubah profil'));
    await _settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Nama lengkap'),
      'Siti R.',
    );
    await tester.tap(find.text('Simpan'));
    await _settle(tester);

    expect(repo.calls, ['update Siti R. 0812']);
    expect(find.text('Siti R.'), findsOneWidget);

    await tester.tap(find.text('Keluar'));
    await _settle(tester);
    expect(find.text('Keluar dari akun?'), findsOneWidget);
  });

  testWidgets('Medical ID is a tab', (tester) async {
    await _pumpShell(tester);

    await tester.tap(find.text('Medical ID').last);
    await _settle(tester);

    expect(find.text('Dibagikan ke paramedis saat darurat'), findsOneWidget);
    expect(find.byTooltip('Ubah Medical ID'), findsOneWidget);
  });
}
