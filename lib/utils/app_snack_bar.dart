import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shared SnackBar display durations for the app.
abstract final class AppSnackBar {
  static const Duration success = Duration(milliseconds: 1200);
  static const Duration error = Duration(milliseconds: 1200);
  static const Duration info = Duration(milliseconds: 1200);

  static Duration forOutcome({required bool isError}) =>
      isError ? error : success;

  static SnackBarThemeData themeData() {
    return const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    );
  }

  /// Shows a floating snack bar with consistent shape and timing.
  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
    Color? backgroundColor,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ??
            (isError ? AppColors.danger : AppColors.brandPrimary),
        behavior: SnackBarBehavior.floating,
        duration: forOutcome(isError: isError),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
