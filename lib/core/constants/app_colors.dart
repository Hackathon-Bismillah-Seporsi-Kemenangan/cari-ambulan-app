import 'package:flutter/material.dart';

/// App color palette for CariAmbulan
class AppColors {
  AppColors._();

  // Primary brand colors
  static const Color primary = Color(0xFF1565C0); // Deep blue
  static const Color primaryLight = Color(0xFF1E88E5); // Light blue
  static const Color primaryDark = Color(0xFF0D47A1); // Dark blue

  // Ambulance / Emergency variant
  static const Color ambulance = Color(0xFFD32F2F); // Emergency red
  static const Color ambulanceLight = Color(0xFFEF5350); // Light red
  static const Color ambulanceDark = Color(0xFFB71C1C); // Dark red
  static const Color ambulanceSurface = Color(0xFFFDECEA); // Red tint
  static const Color primarySurface = Color(0xFFE3F2FD); // Blue tint

  // Neutral
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFFB0B7C3);
  static const Color divider = Color(0xFFE5E7EB);

  // Status colors
  static const Color success = Color(0xFF2E7D32);
  static const Color successSurface = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFF57F17);
  static const Color warningSurface = Color(0xFFFFF8E1);
  static const Color error = Color(0xFFC62828);
  static const Color info = Color(0xFF0277BD);

  // Dark toast over the map
  static const Color toastSurface = Color(0xFF141B2B);
  static const Color toastAccent = Color(0xFF6EE7A0);

  // Voice call screen (same palette as the toast)
  static const Color callSurface = toastSurface;
  static const Color callSurfaceLight = Color(0xFF26324A);
  static const Color callAccent = toastAccent;

  // Driver availability
  static const Color offline = Color(0xFF9CA3AF);
  static const Color offlineLight = Color(0xFFE5E7EB);
}

