import 'package:cari_ambulan/core/constants/user_role.dart';
import 'package:cari_ambulan/features/onboarding/data/onboarding_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a role choice resumes its introduction until completion is saved',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = await OnboardingRepository.create();
      expect(repository.savedRole, isNull);
      expect(repository.isOnboardingComplete, isFalse);

      await repository.selectRole(UserRole.driver);
      final interrupted = await OnboardingRepository.create();
      expect(interrupted.savedRole, UserRole.driver);
      expect(interrupted.isOnboardingComplete, isFalse);

      await interrupted.completeOnboarding(UserRole.driver);
      final returning = await OnboardingRepository.create();
      expect(returning.savedRole, UserRole.driver);
      expect(returning.isOnboardingComplete, isTrue);

      await returning.selectRole(UserRole.patient);
      expect(returning.savedRole, UserRole.patient);
      expect(returning.isOnboardingComplete, isFalse);
    },
  );

  test('old completion and role preferences remain compatible', () async {
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'user_role': 'patient',
    });
    final repository = await OnboardingRepository.create();
    expect(repository.savedRole, UserRole.patient);
    expect(repository.isOnboardingComplete, isTrue);
  });

  for (final role in [null, 'administrator', 42]) {
    test(
      'invalid saved role $role does not bypass first-run selection',
      () async {
        SharedPreferences.setMockInitialValues({
          'onboarding_done': true,
          'user_role': ?role,
        });
        final repository = await OnboardingRepository.create();
        expect(repository.savedRole, isNull);
        expect(repository.isOnboardingComplete, isFalse);
      },
    );
  }

  test(
    'an explicit reset replays selection without removing other preferences',
    () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_done': true,
        'user_role': 'driver',
        'unrelated_setting': 'keep',
      });
      final repository = await OnboardingRepository.create();
      await repository.resetOnboarding();

      expect(repository.savedRole, isNull);
      expect(repository.isOnboardingComplete, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getString('unrelated_setting'),
        'keep',
      );
    },
  );
}
