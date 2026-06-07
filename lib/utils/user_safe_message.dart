import 'package:flutter/foundation.dart';

/// Generic copy shown when an operation fails in release builds.
const String kUserSafeErrorMessage = 'Something went wrong. Please try again.';

/// Returns a safe message for UI; includes details only in debug builds.
String userSafeErrorMessage(Object error) {
  if (kDebugMode) {
    return error.toString().replaceFirst('Exception: ', '');
  }
  return kUserSafeErrorMessage;
}
