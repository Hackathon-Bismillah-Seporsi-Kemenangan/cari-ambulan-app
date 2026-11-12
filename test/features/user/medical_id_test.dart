import 'dart:convert';

import 'package:cari_ambulan_app/core/network/api_client.dart';
import 'package:cari_ambulan_app/features/auth/domain/auth_models.dart';
import 'package:cari_ambulan_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:cari_ambulan_app/features/user/data/medical_repository.dart';
import 'package:cari_ambulan_app/features/user/domain/medical_profile.dart';
import 'package:cari_ambulan_app/features/user/presentation/pages/medical_id_page.dart';
import 'package:cari_ambulan_app/features/user/presentation/widgets/medical_id_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The server's `UserMedicalProfileResource`.
final _json = {
  'id': 1,
  'blood_type': 'O+',
  'allergies': ['Penisilin'],
  'medical_conditions': 'Asma, Hipertensi',
  'birth_date': '1990-05-01',
  'weight_kg': 62.0,
  'height_cm': 165.0,
  'emergency_contact_name': 'Andi Pratama',
  'emergency_contact_relation': 'Suami',
  'emergency_contact_phone': '0812345678',
  'insurance': 'BPJS',
  'share_on_sos': true,
};

class _AuthAs extends AuthNotifier {
  @override
  Future<AuthUser?> build() async =>
      const AuthUser(id: 'u-1', fullName: 'Siti Rahmawati', roles: ['user']);
}

class _FakeMedicalRepo implements MedicalRepository {
  _FakeMedicalRepo(this.profile);

  MedicalProfile profile;
  final saved = <MedicalProfile>[];
  bool failSave = false;
  bool pending = false;

  @override
  Future<MedicalProfile> fetch() async => profile;

  @override
  Future<MedicalProfile> save(MedicalProfile profile) async {
    if (failSave) throw const ApiException('Server sedang sibuk');
    saved.add(profile);
    return this.profile = profile;
  }

  @override
  Future<bool> hasPendingSync() async => pending;
}

Future<void> _pump(WidgetTester tester, _FakeMedicalRepo repo, Widget home) {
  tester.view.physicalSize = const Size(1600, 3200);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        medicalRepositoryProvider.overrideWithValue(repo),
        authProvider.overrideWith(_AuthAs.new),
      ],
      child: MaterialApp(home: Scaffold(body: home)),
    ),
  );
}

void main() {
  test('parses the flat contact columns and text lists', () {
    final profile = MedicalProfile.fromJson(_json);

    expect(profile.bloodType, 'O+');
    expect(profile.conditions, ['Asma', 'Hipertensi']);
    expect(profile.emergencyContact?.relation, 'Suami');
    expect(profile.weightKg, 62);
    expect(profile.isComplete, isTrue);
    expect(
      MedicalProfile.fromJson({'blood_type': 'unknown'}).bloodType,
      isNull,
    );
  });

  test('loads and saves through me/medical-profile', () async {
    final calls = <String>[];
    late Map<String, dynamic> sent;
    final repo = ApiMedicalRepository(
      ApiClient(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          if (request.method == 'PUT') {
            sent = jsonDecode(request.body) as Map<String, dynamic>;
          }
          return http.Response(jsonEncode({'data': _json}), 200);
        }),
      ),
    );

    final profile = await repo.fetch();
    await repo.save(profile.copyWith(bloodType: () => 'A-'));

    expect(calls, [
      'GET /api/v1/me/medical-profile',
      'PUT /api/v1/me/medical-profile',
    ]);
    expect(sent['blood_type'], 'A-');
    expect(sent['emergency_contact_name'], 'Andi Pratama');
    expect(sent['medical_conditions'], ['Asma', 'Hipertensi']);
  });

  testWidgets('home card nudges until the Medical ID is complete', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeMedicalRepo(MedicalProfile.empty),
      const MedicalIdCard(),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lengkapi Medical ID'), findsOneWidget);

    await _pump(
      tester,
      _FakeMedicalRepo(MedicalProfile.fromJson(_json)),
      const MedicalIdCard(key: ValueKey('complete')),
    );
    await tester.pumpAndSettle();
    expect(find.text('O+'), findsOneWidget);
    expect(
      find.text('Alergi: Penisilin · Kontak: Andi Pratama'),
      findsOneWidget,
    );
  });

  testWidgets('editing saves the Medical ID', (tester) async {
    final repo = _FakeMedicalRepo(MedicalProfile.fromJson(_json));
    await _pump(tester, repo, const MedicalIdPage());
    await tester.pumpAndSettle();

    expect(find.text('Siti Rahmawati'), findsOneWidget);
    expect(find.text('Suami — Andi Pratama'), findsOneWidget);

    await tester.tap(find.byTooltip('Ubah Medical ID'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B+'));
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(repo.saved.single.bloodType, 'B+');
    expect(find.text('Medical ID tersimpan.'), findsOneWidget);
    // Back on the Medical ID, showing the new blood type.
    expect(find.text('B+'), findsOneWidget);
  });

  testWidgets('a failed save keeps the form open', (tester) async {
    final repo = _FakeMedicalRepo(MedicalProfile.fromJson(_json))
      ..failSave = true;
    await _pump(tester, repo, const MedicalIdPage());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ubah Medical ID'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Server sedang sibuk'), findsOneWidget);
    expect(find.text('Ubah Medical ID'), findsOneWidget);
  });

  testWidgets('an edit not yet on the server says so', (tester) async {
    final repo = _FakeMedicalRepo(MedicalProfile.fromJson(_json));
    await _pump(tester, repo, const MedicalIdPage());
    await tester.pumpAndSettle();
    expect(find.textContaining('belum tersinkron'), findsNothing);

    repo.pending = true;
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, repo, const MedicalIdPage());
    await tester.pumpAndSettle();
    expect(find.textContaining('belum tersinkron'), findsOneWidget);
  });
}
