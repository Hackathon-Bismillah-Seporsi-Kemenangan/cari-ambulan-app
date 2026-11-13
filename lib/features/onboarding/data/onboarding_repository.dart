import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/user_role.dart';

/// Handles persisting onboarding state and user role to local storage.
class OnboardingRepository {
  static const _keyOnboardingDone = 'onboarding_done';
  static const _keyUserRole = 'user_role';

  final SharedPreferences _prefs;

  OnboardingRepository(this._prefs);

  /// Factory to instantiate repository with SharedPreferences
  static Future<OnboardingRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return OnboardingRepository(prefs);
  }

  /// Returns true if the user has already completed onboarding
  bool get isOnboardingComplete =>
      _prefs.get(_keyOnboardingDone) == true && savedRole != null;

  /// Returns the saved UserRole, or null if not yet set
  UserRole? get savedRole {
    return switch (_prefs.get(_keyUserRole)) {
      'patient' => UserRole.patient,
      'driver' => UserRole.driver,
      _ => null,
    };
  }

  /// Remember the choice even if the app closes during the introduction.
  Future<void> selectRole(UserRole role) async {
    if (!await _prefs.setBool(_keyOnboardingDone, false) ||
        !await _prefs.setString(_keyUserRole, role.name)) {
      throw StateError('Tidak dapat menyimpan pilihan peran.');
    }
  }

  /// Persist that onboarding is done with a chosen role
  Future<void> completeOnboarding(UserRole role) async {
    // Completion is written last so an interrupted write resumes onboarding.
    if (!await _prefs.setString(_keyUserRole, role.name) ||
        !await _prefs.setBool(_keyOnboardingDone, true)) {
      throw StateError('Tidak dapat menyimpan onboarding.');
    }
  }

  /// Explicitly replay onboarding. Normal logout retains these preferences.
  Future<void> resetOnboarding() async {
    await _prefs.remove(_keyOnboardingDone);
    await _prefs.remove(_keyUserRole);
  }
}
