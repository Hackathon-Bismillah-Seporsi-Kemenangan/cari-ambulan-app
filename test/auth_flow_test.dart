import 'dart:async';
import 'dart:convert';

import 'package:cari_ambulan/core/constants/app_strings.dart';
import 'package:cari_ambulan/core/constants/user_role.dart';
import 'package:cari_ambulan/core/network/api_client.dart';
import 'package:cari_ambulan/features/auth/data/auth_repository.dart';
import 'package:cari_ambulan/features/auth/presentation/pages/login_page.dart';
import 'package:cari_ambulan/features/auth/presentation/pages/register_page.dart';
import 'package:cari_ambulan/features/auth/presentation/providers/auth_provider.dart';
import 'package:cari_ambulan/features/driver/presentation/pages/driver_shell.dart';
import 'package:cari_ambulan/features/onboarding/data/onboarding_repository.dart';
import 'package:cari_ambulan/features/onboarding/presentation/pages/access_permission_page.dart';
import 'package:cari_ambulan/features/onboarding/presentation/pages/driver_onboarding_page.dart';
import 'package:cari_ambulan/features/onboarding/presentation/pages/patient_onboarding_page.dart';
import 'package:cari_ambulan/features/onboarding/presentation/pages/role_selection_page.dart';
import 'package:cari_ambulan/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:cari_ambulan/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response _driverSession([int status = 200]) => _json({
  'token': 'registered-driver-token',
  'user': {
    'id': 'driver-1',
    'full_name': 'Budi Santoso',
    'email': 'budi@example.com',
    'phone': '081234567890',
    'roles': ['driver'],
  },
}, status);

AuthRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) => AuthRepository(
  ApiClient(client: MockClient(handler), baseUrl: 'http://api.test'),
);

/// Scrolls [target] into view; on a short screen the bottom buttons aren't
/// built until scrolled to.
Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
}

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text);
  await _reveal(tester, target);
  // The scroll applies on the next frame.
  await tester.pump();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester, String key, String value) async {
  final field = find.byKey(ValueKey(key));
  await _reveal(tester, field);
  await tester.enterText(field, value);
  await tester.pump();
}

/// Fills the account step; for a driver also moves on to "Data ambulans"
/// and fills it.
Future<void> _fillRegistration(
  WidgetTester tester, {
  bool driver = false,
  String password = 'MedicGo123!',
}) async {
  await _fill(tester, 'register_name', 'Budi Santoso');
  await _fill(tester, 'register_email', 'budi@example.com');
  await _fill(tester, 'register_phone', '081234567890');
  if (driver) await _fill(tester, 'register_license', 'SIM-123456');
  await _fill(tester, 'register_password', password);
  if (driver) {
    await _tap(tester, 'Lanjut');
    await _fill(tester, 'register_plate', 'B 1234 ABC');
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 16));
}

class _FailingCompletionRepository extends OnboardingRepository {
  _FailingCompletionRepository(super.prefs);

  bool fail = true;

  @override
  Future<void> completeOnboarding(UserRole role) async {
    if (fail) throw StateError('Storage unavailable');
    await super.completeOnboarding(role);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets(
    'patient introduction finishes at authentication and is remembered',
    (tester) async {
      await tester.pumpWidget(testApp(user: null));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.roleSelectionTitle), findsOneWidget);
      await _tap(tester, AppStrings.continueAsPatient);
      expect(find.byType(PatientOnboardingPage), findsOneWidget);

      await _tap(tester, 'Lanjut');
      await _tap(tester, 'Lanjut');
      await _tap(tester, 'Mulai');

      expect(
        find.text('Izinkan akses agar bantuan cepat sampai'),
        findsOneWidget,
      );
      await _tap(tester, 'Atur nanti');

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Masuk ke CariAmbulan'), findsOneWidget);
      expect(find.byType(DriverShell), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_done'), isTrue);
      expect(prefs.getString('user_role'), 'patient');

      await _unmount(tester);
      await tester.pumpWidget(testApp(user: null));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(RoleSelectionPage), findsNothing);
    },
  );

  testWidgets('the driver is asked for location, then notifications', (
    tester,
  ) async {
    final permissions = FakePermissions();
    SharedPreferences.setMockInitialValues({'user_role': 'driver'});
    await tester.pumpWidget(testApp(user: null, permissions: permissions));
    await tester.pumpAndSettle();
    await _tap(tester, 'Lewati');

    expect(find.text('Izin wajib untuk driver'), findsOneWidget);
    await _tap(tester, 'Kenapa izin ini wajib?');
    expect(find.textContaining('order darurat bisa terlewat'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await _tap(tester, 'Izinkan & Lanjut');
    expect(permissions.asked, ['location', 'notifications']);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Masuk sebagai Driver'), findsOneWidget);
    expect(find.text('MITRA DRIVER'), findsOneWidget);
  });

  testWidgets('a granted permission is not asked again', (tester) async {
    final permissions = FakePermissions()..location = true;
    SharedPreferences.setMockInitialValues({'user_role': 'driver'});
    await tester.pumpWidget(testApp(user: null, permissions: permissions));
    await tester.pumpAndSettle();
    await _tap(tester, 'Lewati');
    await _tap(tester, 'Izinkan & Lanjut');

    expect(permissions.asked, ['notifications']);
  });

  testWidgets(
    'an interrupted driver introduction can go back and change role',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_done': false,
        'user_role': 'driver',
      });
      await tester.pumpWidget(testApp(user: null));
      await tester.pumpAndSettle();
      expect(find.byType(DriverOnboardingPage), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(RoleSelectionPage), findsOneWidget);
      await _tap(tester, AppStrings.rolePatient);
      await _tap(tester, AppStrings.continueAsPatient);
      await _tap(tester, 'Lewati');
      await _tap(tester, 'Atur nanti');

      expect(find.byType(LoginPage), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString('user_role'),
        'patient',
      );
    },
  );

  testWidgets(
    'completion storage failure stays on onboarding and can be retried',
    (tester) async {
      SharedPreferences.setMockInitialValues({'user_role': 'driver'});
      final repository = _FailingCompletionRepository(
        await SharedPreferences.getInstance(),
      );
      await tester.pumpWidget(
        testApp(
          user: null,
          overrides: [
            onboardingRepositoryProvider.overrideWith(
              (ref) async => repository,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await _tap(tester, 'Lewati');
      expect(
        find.text('Onboarding belum tersimpan. Coba lagi.'),
        findsOneWidget,
      );
      expect(find.byType(DriverOnboardingPage), findsOneWidget);
      expect(repository.isOnboardingComplete, isFalse);

      repository.fail = false;
      await _tap(tester, 'Lewati');
      expect(find.byType(AccessPermissionPage), findsOneWidget);
      expect(repository.isOnboardingComplete, isTrue);
    },
  );

  testWidgets(
    'first-run driver signup saves one session and opens the driver dashboard',
    (tester) async {
      final response = Completer<http.Response>();
      final requests = <http.Request>[];
      final repository = _repository((request) {
        requests.add(request);
        return response.future;
      });
      await tester.pumpWidget(
        testApp(
          user: null,
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
        ),
      );
      await tester.pumpAndSettle();

      await _tap(tester, AppStrings.roleDriver);
      await _tap(tester, AppStrings.continueAsDriver);
      await _tap(tester, 'Lewati');
      await _tap(tester, 'Izinkan & Lanjut');
      await _tap(tester, 'Daftar sebagai driver');
      expect(find.text('LANGKAH 1 DARI 2'), findsOneWidget);
      await _fillRegistration(tester, driver: true);
      expect(find.text('LANGKAH 2 DARI 2'), findsOneWidget);
      await _tap(tester, 'Ambulans ICU Bergerak');
      final submit = find.widgetWithText(FilledButton, 'Daftar');
      await _reveal(tester, submit);
      await tester.pump();
      await tester.tap(submit);
      await tester.pump();

      // A second tap, or back, while the first request is pending does
      // nothing.
      await tester.tap(
        find.widgetWithText(FilledButton, 'Memproses...'),
        warnIfMissed: false,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(RegisterPage), findsOneWidget);
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/api/v1/auth/register');
      final body = jsonDecode(requests.single.body);
      expect(body, containsPair('role', 'driver'));
      expect(body, containsPair('license_number', 'SIM-123456'));
      expect(body, containsPair('plate_number', 'B 1234 ABC'));
      expect(body, containsPair('vehicle_type', 'Ambulans ICU Bergerak'));
      // Asked once in the design; the server still wants both.
      expect(body, containsPair('password_confirmation', 'MedicGo123!'));

      response.complete(_driverSession(201));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(DriverShell), findsOneWidget);
      expect(find.byType(RegisterPage), findsNothing);
      expect(
        await const FlutterSecureStorage().read(key: 'auth_token'),
        'registered-driver-token',
      );

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(RegisterPage), findsNothing);
      await _unmount(tester);
    },
  );

  testWidgets('back on "Data ambulans" returns to step 1 with the input kept', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'user_role': 'driver',
    });
    await tester.pumpWidget(testApp(user: null));
    await tester.pumpAndSettle();
    await _tap(tester, 'Daftar sebagai driver');
    await _fillRegistration(tester, driver: true);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('LANGKAH 1 DARI 2'), findsOneWidget);
    expect(find.text('budi@example.com'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('a server error on step 2 shows on step 1, by the email', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'user_role': 'driver',
    });
    final repository = _repository(
      (_) async => _json({
        'errors': {
          'email': ['Email ini sudah terdaftar. Silakan masuk.'],
        },
      }, 422),
    );
    await tester.pumpWidget(
      testApp(
        user: null,
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      ),
    );
    await tester.pumpAndSettle();
    await _tap(tester, 'Daftar sebagai driver');
    await _fillRegistration(tester, driver: true);
    await _tap(tester, 'Daftar');

    expect(find.text('LANGKAH 1 DARI 2'), findsOneWidget);
    expect(
      find.text('Email ini sudah terdaftar. Silakan masuk.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'patient signup validates the password and displays API errors without signing in',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_done': true,
        'user_role': 'patient',
      });
      final requests = <http.Request>[];
      final repository = _repository((request) async {
        requests.add(request);
        return _json({
          'errors': {
            'email': ['Email ini sudah terdaftar. Silakan masuk.'],
          },
        }, 422);
      });
      await tester.pumpWidget(
        testApp(
          user: null,
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'Daftar');
      expect(find.text('Buat akun CariAmbulan'), findsOneWidget);
      expect(find.byKey(const ValueKey('register_license')), findsNothing);
      await _fillRegistration(tester, password: 'short');
      await _tap(tester, 'Daftar');
      expect(find.text('Kata sandi minimal 8 karakter'), findsOneWidget);
      expect(requests, isEmpty);

      await _fill(tester, 'register_password', 'MedicGo123!');
      await _tap(tester, 'Daftar');
      expect(
        find.text('Email ini sudah terdaftar. Silakan masuk.'),
        findsOneWidget,
      );
      expect(jsonDecode(requests.single.body), containsPair('role', 'user'));
      expect(find.byType(RegisterPage), findsOneWidget);
      expect(
        await const FlutterSecureStorage().read(key: 'auth_token'),
        isNull,
      );
    },
  );

  testWidgets(
    'login uses the server role and logout clears pushed routes while retaining onboarding',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_done': true,
        'user_role': 'patient',
      });
      final repository = _repository((request) async {
        expect(request.url.path, '/api/v1/auth/login');
        return _driverSession();
      });
      await tester.pumpWidget(
        testApp(
          user: null,
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
        ),
      );
      await tester.pumpAndSettle();
      await _fill(tester, 'login_email', 'budi@example.com');
      await _fill(tester, 'login_password', 'MedicGo123!');
      await tester.ensureVisible(find.text('Masuk'));
      await tester.tap(find.text('Masuk'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(DriverShell), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CariAmbulanApp)),
      );
      Navigator.of(tester.element(find.byType(DriverShell))).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Private pushed screen')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Private pushed screen'), findsOneWidget);

      await container.read(authProvider.notifier).logout();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Private pushed screen'), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(RoleSelectionPage), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getBool('onboarding_done'),
        isTrue,
      );
      await _unmount(tester);
    },
  );

  for (final role in UserRole.values) {
    testWidgets(
      '${role.name} onboarding and auth fit a small screen with large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.8;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );

        await tester.pumpWidget(testApp(user: null));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (role.isDriver) await _tap(tester, AppStrings.roleDriver);
        await _tap(
          tester,
          role.isPatient
              ? AppStrings.continueAsPatient
              : AppStrings.continueAsDriver,
        );
        expect(tester.takeException(), isNull);
        await _tap(tester, 'Lewati');
        expect(tester.takeException(), isNull);
        await _tap(
          tester,
          role.isPatient ? 'Izinkan Semua' : 'Izinkan & Lanjut',
        );
        expect(tester.takeException(), isNull);
        await _tap(tester, role.isPatient ? 'Daftar' : 'Daftar sebagai driver');
        expect(tester.takeException(), isNull);
        await _tap(tester, role.isPatient ? 'Daftar' : 'Lanjut');
        expect(tester.takeException(), isNull);
        expect(find.text('Nama lengkap wajib diisi'), findsOneWidget);
        if (role.isDriver) {
          await _fillRegistration(tester, driver: true);
          expect(tester.takeException(), isNull);
          expect(find.text('Data ambulans'), findsOneWidget);
        }
      },
    );
  }
}
