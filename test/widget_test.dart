import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cari_ambulan/features/auth/domain/auth_models.dart';

import 'test_app.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('driver home shows offline state after loading', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump(); // resolve the signed-in session
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('OFFLINE'), findsOneWidget);
    expect(find.text('Siap mulai bertugas?'), findsOneWidget);
  });

  testWidgets('shows role selection on the first signed-out launch', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(user: null));
    await tester.pumpAndSettle();

    expect(find.text('SigapMed'), findsOneWidget);
    expect(find.text('Pilih peran Anda'), findsOneWidget);
    expect(find.text('Pasien atau keluarga'), findsOneWidget);
    expect(find.text('Pengemudi ambulans'), findsOneWidget);
    expect(find.text('Masuk'), findsNothing);
  });

  testWidgets('shows login when onboarding was already completed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'user_role': 'patient',
    });

    await tester.pumpWidget(testApp(user: null));
    await tester.pumpAndSettle();

    expect(find.text('Masuk ke SigapMed'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Daftar'), findsOneWidget);
  });

  testWidgets('tells an account without an app role to sign in again', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        user: const AuthUser(
          id: 'a-1',
          fullName: 'Admin RS',
          roles: ['hospital_admin'],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Akun ini belum didukung aplikasi'), findsOneWidget);
  });
}
