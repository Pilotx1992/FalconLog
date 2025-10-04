import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../services/enhanced_auth_service.dart';

// Provider for enhanced auth service
final enhancedAuthServiceProvider = Provider<EnhancedAuthService>((ref) {
  return EnhancedAuthService();
});

// Provider for biometric enabled state
final biometricEnabledProvider =
    StateNotifierProvider<BiometricEnabledNotifier, bool>((ref) {
  return BiometricEnabledNotifier(ref);
});

class BiometricEnabledNotifier extends StateNotifier<bool> {
  final Ref _ref;

  BiometricEnabledNotifier(this._ref) : super(false) {
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    try {
      final authService = _ref.read(enhancedAuthServiceProvider);
      final isEnabled = await authService.isBiometricEnabled();
      state = isEnabled;
    } catch (e) {
      state = false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      final authService = _ref.read(enhancedAuthServiceProvider);
      if (enabled) {
        await authService.enableBiometricAuth();
      } else {
        await authService.disableBiometricAuth();
      }
      state = enabled;
    } catch (e) {
      // Revert state on error
      state = !enabled;
      rethrow;
    }
  }

  Future<void> refresh() async {
    await _loadBiometricState();
  }
}

// Provider for checking biometric availability
final biometricAvailabilityProvider =
    FutureProvider<BiometricAvailability>((ref) async {
  try {
    final authService = ref.read(enhancedAuthServiceProvider);
    final isAvailable = await authService.isBiometricAvailable();
    final availableBiometrics = await authService.getAvailableBiometrics();

    return BiometricAvailability(
      isDeviceSupported: isAvailable,
      canCheckBiometrics: isAvailable,
      hasEnrolledBiometrics: availableBiometrics.isNotEmpty,
      availableBiometrics: availableBiometrics,
    );
  } catch (e) {
    return const BiometricAvailability(
      isDeviceSupported: false,
      canCheckBiometrics: false,
      hasEnrolledBiometrics: false,
      availableBiometrics: [],
    );
  }
});

// Provider for biometric setup state
final biometricSetupProvider =
    StateNotifierProvider<BiometricSetupNotifier, BiometricSetupState>((ref) {
  return BiometricSetupNotifier(ref);
});

class BiometricSetupNotifier extends StateNotifier<BiometricSetupState> {
  final Ref _ref;

  BiometricSetupNotifier(this._ref) : super(const BiometricSetupState.idle());

  Future<void> setupBiometric() async {
    state = const BiometricSetupState.loading();

    try {
      final authService = _ref.read(enhancedAuthServiceProvider);
      await authService.enableBiometricAuth();
      state = const BiometricSetupState.success();
    } catch (e) {
      state = BiometricSetupState.error(e.toString());
    }
  }

  Future<void> disableBiometric() async {
    state = const BiometricSetupState.loading();

    try {
      final authService = _ref.read(enhancedAuthServiceProvider);
      await authService.disableBiometricAuth();
      state = const BiometricSetupState.disabled();
    } catch (e) {
      state = BiometricSetupState.error(e.toString());
    }
  }

  void reset() {
    state = const BiometricSetupState.idle();
  }
}

// Data class for biometric availability
class BiometricAvailability {
  final bool isDeviceSupported;
  final bool canCheckBiometrics;
  final bool hasEnrolledBiometrics;
  final List<BiometricType> availableBiometrics;

  const BiometricAvailability({
    required this.isDeviceSupported,
    required this.canCheckBiometrics,
    required this.hasEnrolledBiometrics,
    required this.availableBiometrics,
  });

  bool get isFullyAvailable =>
      isDeviceSupported && canCheckBiometrics && hasEnrolledBiometrics;

  String get biometricTypeName {
    if (availableBiometrics.isEmpty) return 'None';
    if (availableBiometrics.contains(BiometricType.face)) return 'Face ID';
    if (availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    }
    if (availableBiometrics.contains(BiometricType.strong)) {
      return 'Strong Biometric';
    }
    if (availableBiometrics.contains(BiometricType.weak)) {
      return 'Weak Biometric';
    }
    return 'Biometric';
  }

  String get statusMessage {
    if (!isDeviceSupported) {
      return 'Device not supported';
    } else if (!canCheckBiometrics) {
      return 'Biometrics not available';
    } else if (!hasEnrolledBiometrics) {
      return 'No biometrics enrolled';
    } else {
      return 'Available: $biometricTypeName';
    }
  }
}

// State for biometric setup
abstract class BiometricSetupState {
  const BiometricSetupState();

  const factory BiometricSetupState.idle() = _Idle;
  const factory BiometricSetupState.loading() = _Loading;
  const factory BiometricSetupState.success() = _Success;
  const factory BiometricSetupState.disabled() = _Disabled;
  const factory BiometricSetupState.error(String message) = _Error;
}

class _Idle extends BiometricSetupState {
  const _Idle();
}

class _Loading extends BiometricSetupState {
  const _Loading();
}

class _Success extends BiometricSetupState {
  const _Success();
}

class _Disabled extends BiometricSetupState {
  const _Disabled();
}

class _Error extends BiometricSetupState {
  final String message;
  const _Error(this.message);
}
