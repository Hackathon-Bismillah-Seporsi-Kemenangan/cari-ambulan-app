import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/app_log.dart';
import '../domain/medical_profile.dart';

/// The last Medical ID on this phone, so it shows without a connection, and
/// whether it still has to reach the server.
class MedicalStore {
  const MedicalStore(this.userId);

  final String userId;

  static const _prefix = 'medical_profile_';

  String get _key => '$_prefix$userId';

  Future<({MedicalProfile profile, bool pending})?> read() async {
    try {
      final text = (await SharedPreferences.getInstance()).getString(_key);
      if (text == null) return null;
      final json = jsonDecode(text) as Map<String, dynamic>;
      return (
        profile: MedicalProfile.fromJson(
          json['profile'] as Map<String, dynamic>,
        ),
        pending: json['pending'] as bool? ?? false,
      );
    } catch (e) {
      AppLog.warn('MEDICAL', 'Saved Medical ID unreadable', e);
      return null;
    }
  }

  Future<void> write(MedicalProfile profile, {required bool pending}) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode({'profile': profile.toJson(), 'pending': pending}),
      );
    } catch (e) {
      AppLog.warn('MEDICAL', 'Medical ID not saved on the phone', e);
    }
  }

  /// Health data stays off a phone once its owner signs out.
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (key.startsWith(_prefix)) await prefs.remove(key);
      }
    } catch (e) {
      AppLog.warn('MEDICAL', 'Saved Medical IDs not cleared', e);
    }
  }
}
