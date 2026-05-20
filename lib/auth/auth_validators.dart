final RegExp _emailPattern = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$');

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

/// Register: Firebase minimum length.
String? validateRegisterPassword(String? value) {
  if (value == null || value.isEmpty) {
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
  if (value == null || value.trim().isEmpty) {
    return 'Please enter your full name.';
  }
  if (value.trim().length < 2) {
    return 'Name must be at least 2 characters.';
  }
  return null;
}
