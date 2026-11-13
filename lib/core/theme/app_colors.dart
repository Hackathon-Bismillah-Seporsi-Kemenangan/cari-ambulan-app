import 'package:flutter/material.dart';

/// Shared brand palette. Keep all colors here so User, Driver, and Auth
/// screens stay consistent.
abstract final class AppColors {
  static const primary = Color(0xFF1A5FD0);
  static const primaryLight = Color(0xFFE3EDFC);

  static const emergency = Color(0xFFD32F2F);
  static const emergencyLight = Color(0xFFFDECEC);
  static const emergencyDark = Color(0xFFB71C1C);

  static const online = Color(0xFF2E7D32);
  static const onlineLight = Color(0xFFE8F5E9);
  static const offline = Color(0xFF8A9099);
  static const offlineLight = Color(0xFFE4E6EA);

  /// Dark panel for the reporter's voice call during an order.
  static const callSurface = Color(0xFF141B2B);
  static const callSurfaceLight = Color(0xFF26324A);
  static const callAccent = Color(0xFF6EE7A0);

  static const warning = Color(0xFF9A6B00);
  static const warningLight = Color(0xFFFFF7DC);

  static const surface = Colors.white;
  static const background = Color(0xFFF3F4F6);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
  static const divider = Color(0xFFE5E7EB);
}
