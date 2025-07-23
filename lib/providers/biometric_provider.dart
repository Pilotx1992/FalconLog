import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../services/biometric_auth_service.dart';

// Provider for biometric enabled state
final biometricEnabledProvider = StateNotifierProvider<BiometricEnabledNotifier, bool>((ref) {
  return BiometricEnabledNotifier();
});

class BiometricEnabledNotifier extends StateNotifier<bool> {
  BiometricEnabledNotifier() : super(false) {
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    try {
      final isEnabled = await BiometricAuthService.isBiometricEnabled();
      state = isEnabled;
    } catch (e) {
      state = false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      await BiometricAuthService.setBiometricEnabled(enabled);
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
final biometricAvailabilityProvider = FutureProvider<BiometricAvailability>((ref) async {
  try {
    final isDeviceSupported = await BiometricAuthService.isDeviceSupported();
    final canCheckBiometrics = await BiometricAuthService.canCheckBiometrics();
    final hasEnrolledBiometrics = await BiometricAuthService.hasEnrolledBiometrics();
    final availableBiometrics = await BiometricAuthService.getAvailableBiometrics();

    return BiometricAvailability(
      isDeviceSupported: isDeviceSupported,
      canCheckBiometrics: canCheckBiometrics,
      hasEnrolledBiometrics: hasEnrolledBiometrics,
      availableBiometrics: availableBiometrics,
    );
  } catch (e) {
    return BiometricAvailability(
      isDeviceSupported: false,
      canCheckBiometrics: false,
      hasEnrolledBiometrics: false,
      availableBiometrics: [],
    );
  }
});

// Provider for biometric setup state
final biometricSetupProvider = StateNotifierProvider<BiometricSetupNotifier, BiometricSetupState>((ref) {
  return BiometricSetupNotifier();
});

class BiometricSetupNotifier extends StateNotifier<BiometricSetupState> {
  BiometricSetupNotifier() : super(const BiometricSetupState.idle());

  Future<void> setupBiometric() async {
    state = const BiometricSetupState.loading();
    
    try {
      final result = await BiometricAuthService.setupBiometricAuth();
      
      if (result.isSuccess) {
        state = const BiometricSetupState.success();
      } else {
        state = BiometricSetupState.error(result.message);
      }
    } catch (e) {
      state = BiometricSetupState.error(e.toString());
    }
  }

  Future<void> disableBiometric() async {
    state = const BiometricSetupState.loading();
    
    try {
      await BiometricAuthService.disableBiometricAuth();
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

  String get biometricTypeName => 
    BiometricAuthService.getBiometricTypeName(availableBiometrics);

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
