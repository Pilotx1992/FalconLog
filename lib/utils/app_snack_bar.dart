import 'package:flutter/material.dart';

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
}
