import 'package:flutter/material.dart';

/// Centralized harmonious color palette for FalconLog.
/// Adjust here to propagate across the app.
class AppColors {
  // Dark surfaces
  static const Color surfaceUltraDark = Color(0xFF0B1220);
  static const Color surfaceDark = Color(0xFF0F2033);
  static const Color surfaceMid = Color(0xFF112E46);
  static const Color surfaceAccent = Color(0xFF0D1C2C);

  // Brand gradient (primary)
  static const Color brandPrimary = Color(0xFF1D4ED8); // Indigo 600
  static const Color brandPrimaryLight = Color(0xFF3B82F6); // Blue 500

  // Accent / supportive
  static const Color accentAqua = Color(0xFF7DD3FC);
  static const Color accentSoftBlue = Color(0xFF60A5FA);
  static const Color accentMint = Color(0xFF34D399);

  // Text / neutrals
  static const Color textPrimary = Color(0xFFE2E8F0); // slate 200
  static const Color textSecondary = Color(0xFF94A3B8); // slate 400
  static const Color textFaint = Color(0xFF64748B); // slate 500

  // Semantic
  static const Color danger = Colors.redAccent;
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);

  // Utility opacities
  static Color overlayLight(double opacity) => Colors.white.withOpacity(opacity);
  static Color overlayDark(double opacity) => Colors.black.withOpacity(opacity);
}
