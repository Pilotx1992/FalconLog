/// Messages for blocked email/password sign-up when another provider owns the email.
const String kGoogleAccountExistsSignupMessage =
    'This email is already registered with Google. Please sign in with Google.';

const String kPasswordAccountExistsSignupMessage =
    'An account already exists with this email. Please log in.';

/// Shown when Google sign-in is attempted for an email/password account.
const String kGoogleSignInPasswordAccountExistsMessage =
    'This email is already registered with email and password. '
    'Please sign in with email and password.';

const String kOtherProviderSignupMessage =
    'This email is already registered with another sign-in method. '
    'Please sign in using that method instead.';

/// Shown when [fetchSignInMethods] is unavailable and Firebase rejects creation.
const String kSignupEmailAlreadyExistsMessage =
    'An account already exists with this email. '
    'Sign in instead. If you use Google, choose Continue with Google.';

/// Result of evaluating existing sign-in methods before password sign-up.
class SignupGuardDecision {
  const SignupGuardDecision._({required this.allowSignup, this.blockMessage});

  final bool allowSignup;
  final String? blockMessage;

  factory SignupGuardDecision.allow() =>
      const SignupGuardDecision._(allowSignup: true);

  factory SignupGuardDecision.block(String message) =>
      SignupGuardDecision._(allowSignup: false, blockMessage: message);
}

/// Pure policy: given Firebase sign-in method ids, should password sign-up proceed?
SignupGuardDecision evaluateSignInMethodsForPasswordSignup(
  List<String> methods,
) {
  if (methods.isEmpty) {
    return SignupGuardDecision.allow();
  }

  final hasGoogle = methods.contains('google.com');
  final hasPassword = methods.contains('password');

  if (hasGoogle && !hasPassword) {
    return SignupGuardDecision.block(kGoogleAccountExistsSignupMessage);
  }
  if (hasPassword) {
    return SignupGuardDecision.block(kPasswordAccountExistsSignupMessage);
  }

  return SignupGuardDecision.block(kOtherProviderSignupMessage);
}

/// Fetches sign-in methods for [email], or `null` when the platform cannot
/// enumerate methods (firebase_auth 6.x removed [FirebaseAuth.fetchSignInMethodsForEmail]).
typedef FetchSignInMethodsFn = Future<List<String>?> Function(String email);

/// Best-effort pre-check before [createUserWithEmailAndPassword].
Future<SignupGuardDecision> checkPasswordSignupAllowed(
  String email, {
  required FetchSignInMethodsFn fetchSignInMethods,
}) async {
  final methods = await fetchSignInMethods(email.trim());
  if (methods == null) {
    return SignupGuardDecision.allow();
  }
  return evaluateSignInMethodsForPasswordSignup(methods);
}
