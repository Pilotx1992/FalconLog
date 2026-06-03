import 'dart:ui';

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Shared visual system for Backup & Restore screens.
///
/// The goal here is to keep the backup UI premium, calm, and consistent with
/// FalconLog's dark cockpit-style surfaces while avoiding heavy visual noise.
abstract final class BackupUiTheme {
  static const Color scaffoldBg = AppColors.surfaceUltraDark;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textMuted = AppColors.textSecondary;
  static const Color accent = AppColors.brandPrimary;
  static const Color accentLight = AppColors.brandPrimaryLight;
  static const Color success = AppColors.success;
  static const Color warning = AppColors.warning;
  static const Color danger = AppColors.danger;

  static const LinearGradient headerGradient = LinearGradient(
    colors: [
      AppColors.surfaceUltraDark,
      AppColors.surfaceDark,
      AppColors.surfaceMid,
    ],
    stops: [0.0, 0.58, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [AppColors.brandPrimary, AppColors.brandPrimaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ctaGradient = LinearGradient(
    colors: [AppColors.brandPrimary, AppColors.accentSoftBlue],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static LinearGradient dangerGradient = LinearGradient(
    colors: [AppColors.danger, AppColors.danger.withValues(alpha: 0.74)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color get panelFill => AppColors.surfaceDark.withValues(alpha: 0.78);
  static Color get elevatedPanelFill =>
      AppColors.surfaceMid.withValues(alpha: 0.74);
  static Color get panelStroke =>
      AppColors.surfaceAccent.withValues(alpha: 0.9);
  static Color get softStroke => AppColors.textPrimary.withValues(alpha: 0.08);
  static Color get glow => AppColors.brandPrimary.withValues(alpha: 0.2);

  static BoxDecoration pageGlow({required Color color}) => BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      );

  static BoxDecoration cardDecoration({double radius = 26}) => BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceDark.withValues(alpha: 0.96),
            AppColors.surfaceMid.withValues(alpha: 0.68),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: panelStroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: AppColors.brandPrimary.withValues(alpha: 0.05),
            blurRadius: 40,
            offset: const Offset(0, 10),
          ),
        ],
      );

  static Widget glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
    double radius = 26,
    bool enableBlur = false,
  }) {
    final container = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: panelFill,
        border: Border.all(color: panelStroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );

    if (!enableBlur) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: container,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: container,
      ),
    );
  }

  static Widget sheetHandle() {
    return Container(
      width: 42,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }

  static Widget sectionTitle(
    String title, {
    String? subtitle,
    IconData? icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon ?? Icons.auto_awesome_rounded,
              color: Colors.white, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  letterSpacing: 0.1,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.32,
                    color: textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static Widget iconBadge(
    IconData icon, {
    Color? tint,
    double size = 44,
    double radius = 16,
  }) {
    final badgeColor = tint ?? AppColors.brandPrimaryLight;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: badgeColor.withValues(alpha: 0.22)),
      ),
      child: Icon(icon, size: size * 0.48, color: badgeColor),
    );
  }

  static Widget infoBanner({
    required IconData icon,
    required String message,
    required Color tone,
    String? title,
    Color? titleColor,
    Color? messageColor,
  }) {
    final resolvedTitleColor = titleColor ?? textPrimary;
    final resolvedMessageColor = messageColor ?? textPrimary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: 0.26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: tone),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title,
                    style: TextStyle(
                      color: resolvedTitleColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  message,
                  style: TextStyle(
                    color: resolvedMessageColor,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static ButtonStyle ghostButtonStyle({Color? color, double radius = 18}) {
    final foreground = color ?? AppColors.textPrimary;
    return OutlinedButton.styleFrom(
      foregroundColor: foreground,
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      side: BorderSide(color: foreground.withValues(alpha: 0.28)),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    );
  }

  static ButtonStyle filledButtonStyle({double radius = 18}) {
    return FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      backgroundColor: accent,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    );
  }

  static SnackBar styledSnack(String message) {
    return SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: AppColors.surfaceMid,
      behavior: SnackBarBehavior.floating,
      elevation: 8,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      duration: const Duration(seconds: 2),
    );
  }

  static SnackBar successSnack(String message) {
    return SnackBar(
      content: Text(
        message,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      backgroundColor: success,
      behavior: SnackBarBehavior.floating,
      elevation: 8,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      duration: const Duration(seconds: 2),
    );
  }

  static SnackBar errorSnack(String message) {
    return SnackBar(
      content: Text(
        message,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      backgroundColor: danger,
      behavior: SnackBarBehavior.floating,
      elevation: 8,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      duration: const Duration(seconds: 3),
    );
  }
}
