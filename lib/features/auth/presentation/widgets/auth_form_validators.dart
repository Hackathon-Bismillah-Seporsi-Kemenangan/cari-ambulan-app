import 'dart:convert';

abstract final class AuthFormValidators {
  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email wajib diisi';
    if (email.length > 100) return 'Email maksimal 100 karakter';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Masukkan alamat email yang valid';
    }
    return null;
  }

  static String? requiredText(String? value, String label, {int? maxLength}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label wajib diisi';
    if (maxLength != null && text.runes.length > maxLength) {
      return '$label maksimal $maxLength karakter';
    }
    return null;
  }

  static String? newPassword(String? value) {
    if (value == null || value.trim().isEmpty) return 'Kata sandi wajib diisi';
    if (value.runes.length < 8) return 'Kata sandi minimal 8 karakter';
    if (utf8.encode(value).length > 72) {
      return 'Kata sandi terlalu panjang (maksimal 72 byte)';
    }
    return null;
  }
}
