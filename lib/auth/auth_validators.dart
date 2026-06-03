final RegExp _emailPattern = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$');
final RegExp _controlCharacters = RegExp(r'[\x00-\x1F\x7F]');

const int _maxDisplayNameLength = 100;

String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Please enter your email.';
  }
  if (!_emailPattern.hasMatch(value.trim())) {
    return 'Please enter a valid email address.';
  }
  return null;
}

/// Login: password must be non-empty only.
String? validateLoginPassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter your password.';
  }
  return null;
}

/// Register: Firebase minimum length; no whitespace-only passwords.
String? validateRegisterPassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter a password.';
  }
  if (value.trim().isEmpty) {
    return 'Please enter a password.';
  }
  if (value.length < 6) {
    return 'Password is too weak. Use at least 6 characters.';
  }
  return null;
}

String? validateConfirmPassword(String? value, String password) {
  if (value == null || value.isEmpty) {
    return 'Please confirm your password.';
  }
  if (value != password) {
    return 'Passwords do not match.';
  }
  return null;
}

String? validateDisplayName(String? value) {
  if (value == null) {
    return 'Please enter your full name.';
  }
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'Please enter your full name.';
  }
  if (trimmed.length < 2) {
    return 'Name must be at least 2 characters.';
  }
  if (trimmed.length > _maxDisplayNameLength) {
    return 'Name must be at most $_maxDisplayNameLength characters.';
  }
  if (_controlCharacters.hasMatch(trimmed)) {
    return 'Please enter a valid name.';
  }
  return null;
}
