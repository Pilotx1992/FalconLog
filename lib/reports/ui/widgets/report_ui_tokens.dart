import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Shared visual tokens for the flight report export screen.
abstract final class ReportUiTokens {
  static const LinearGradient appBarGradient = LinearGradient(
    colors: [Color(0xFF1a237e), Color(0xFF3949ab), Color(0xFF5e35b1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient tileGradient = LinearGradient(
    colors: [Color(0xFF3949ab), Color(0xFF5e35b1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient introStripGradient = LinearGradient(
    colors: [
      Color(0xFFB3E1FC),
      Color(0xFFE3F1FF),
      Color(0xFFE8D5E2),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient bodyGradient = LinearGradient(
    colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Color previewTint = Color(0xFFE0F4FF);
  static const Color previewBorder = Color(0xFF87CEEB);
  static const Color titleText = Color(0xFF1E293B);
  static const Color labelText = Color(0xFF64748B);
  static const Color faintText = Color(0xFF94A3B8);

  static const double cardRadius = 20;
  static const double chipRadius = 16;
  static const double buttonRadius = 16;

  static Color spinnerColor = AppColors.brandPrimary;

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}
