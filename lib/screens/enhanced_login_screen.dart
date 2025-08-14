import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/enhanced_auth_service.dart';
import '../providers/enhanced_biometric_provider.dart';
import '../widgets/auth_wrapper.dart' show authStateProvider;

// Provider for the enhanced auth service
final enhancedAuthServiceProvider = Provider<EnhancedAuthService>((ref) {
  return EnhancedAuthService();
});

// Provider for auth loading state
final authLoadingProvider = StateProvider<bool>((ref) => false);

class EnhancedLoginScreen extends ConsumerStatefulWidget {
  const EnhancedLoginScreen({super.key});

  @override
  ConsumerState<EnhancedLoginScreen> createState() => _EnhancedLoginScreenState();
}

class _EnhancedLoginScreenState extends ConsumerState<EnhancedLoginScreen> 
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isRegisterMode = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _animationController.forward();
    
    // Auto-try biometric if available and enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAutoAuthentication();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _tryAutoAuthentication() async {
    final authService = ref.read(enhancedAuthServiceProvider);
    final preferredMethod = await authService.getPreferredSignInMethod();
    
    if (preferredMethod == AuthMethod.biometric) {
      await _signInWithBiometric();
    }
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(authLoadingProvider.notifier).state = true;

    try {
      final authService = ref.read(enhancedAuthServiceProvider);
      
      if (_isRegisterMode) {
        await authService.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (!mounted) return;
        _showSnackBar('Account created successfully!', Colors.green);
      } else {
        await authService.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (!mounted) return;
        _showSnackBar('Login successful!', Colors.green);
      }
      
      ref.invalidate(authStateProvider);
    } catch (e) {
      String errorMessage = 'An error occurred';
      
      if (e.toString().contains('wrong-password')) {
        errorMessage = 'Invalid password. Please try again.';
      } else if (e.toString().contains('user-not-found')) {
        errorMessage = 'No account found with this email.';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Please enter a valid email address.';
      } else if (e.toString().contains('too-many-requests')) {
        errorMessage = 'Too many failed attempts. Please try again later.';
      } else if (e.toString().contains('network-request-failed')) {
        errorMessage = 'Network error. Please check your connection.';
      } else if (e.toString().contains('invalid-credential')) {
        errorMessage = 'Invalid credentials. Please check your email and password.';
      } else {
        // Extract Firebase error message if available
        final errorText = e.toString();
        if (errorText.contains('FirebaseAuthException')) {
          final match = RegExp(r'\] (.+)$').firstMatch(errorText);
          if (match != null) {
            errorMessage = match.group(1) ?? errorMessage;
          }
        } else {
          errorMessage = errorText;
        }
      }
      
      if (mounted) {
        _showSnackBar(errorMessage, Colors.red);
      }
    } finally {
      if (mounted) {
        ref.read(authLoadingProvider.notifier).state = false;
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    ref.read(authLoadingProvider.notifier).state = true;

    try {
      final authService = ref.read(enhancedAuthServiceProvider);
      final result = await authService.signInWithGoogle();
      
      if (result != null) {
        if (!mounted) return;
        _showSnackBar('Google sign-in successful!', Colors.green);
        ref.invalidate(authStateProvider);
      }
    } catch (e) {
      String errorMessage = 'Google sign-in failed';
      
      if (e.toString().contains('Google Play Services') || 
          e.toString().contains('SERVICE_INVALID')) {
        errorMessage = 'Google Play Services not available. This feature works on real devices only.';
      } else if (e.toString().contains('sign_in_canceled')) {
        errorMessage = 'Google sign-in was cancelled.';
      } else if (e.toString().contains('network_error')) {
        errorMessage = 'Network error. Please check your connection.';
      } else if (e.toString().contains('under maintenance')) {
        errorMessage = 'Google Sign-In is temporarily unavailable. Please use email/password.';
      } else {
        errorMessage = 'Google sign-in failed. ${e.toString()}';
      }
      
      if (mounted) {
        _showSnackBar(errorMessage, Colors.orange);
      }
    } finally {
      if (mounted) {
        ref.read(authLoadingProvider.notifier).state = false;
      }
    }
  }

  Future<void> _signInWithBiometric() async {
    try {
      final authService = ref.read(enhancedAuthServiceProvider);
      final result = await authService.signInWithBiometric();
      
      if (result != null) {
        if (!mounted) return;
        _showSnackBar('Biometric authentication successful!', Colors.green);
        ref.invalidate(authStateProvider);
      }
    } catch (e) {
      String errorMessage = 'Biometric authentication failed';
      
      if (e.toString().contains('No biometric credentials saved')) {
        errorMessage = 'Please sign in with email first to enable biometric login.';
      } else if (e.toString().contains('BiometricException: UserCancel')) {
        errorMessage = 'Biometric authentication was cancelled.';
      } else if (e.toString().contains('not available')) {
        errorMessage = 'Biometric authentication is not available on this device.';
      } else if (e.toString().contains('PlatformException')) {
        // Don't show error for auto-try failures
        if (e.toString().contains('No biometric credentials saved')) {
          return;
        }
        errorMessage = 'Biometric authentication failed. Please try again.';
      }
      
      // Only show error if it's a user-initiated action
      if (errorMessage != 'Biometric authentication failed') {
        if (mounted) {
          _showSnackBar(errorMessage, Colors.orange);
        }
      }
    }
  }

  Future<void> _enableBiometric() async {
    try {
      final authService = ref.read(enhancedAuthServiceProvider);
      await authService.enableBiometricAuth();
      if (!mounted) return;
      _showSnackBar('Biometric authentication enabled!', Colors.green);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString(), Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                color == Colors.green ? Icons.check_circle : Icons.error,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);
    final biometricAvailable = ref.watch(biometricAvailabilityProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1a237e),
              Color(0xFF3949ab),
              Color(0xFF5e35b1),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildAuthCard(isLoading, biometricAvailable),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthCard(bool isLoading, AsyncValue<BiometricAvailability> biometricAvailable) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildAuthMethods(isLoading, biometricAvailable),
            const SizedBox(height: 24),
            _buildEmailForm(isLoading),
            const SizedBox(height: 24),
            _buildActionButtons(isLoading),
            const SizedBox(height: 16),
            _buildToggleMode(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF1a237e).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.flight_rounded,
            size: 40,
            color: Color(0xFF1a237e),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'FALCON LOG',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1a237e),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isRegisterMode ? 'Create Your Account' : 'Welcome Back',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildAuthMethods(bool isLoading, AsyncValue<BiometricAvailability> biometricAvailable) {
    return Column(
      children: [
        // Google Sign-In Button
        _buildSocialButton(
          onPressed: isLoading ? null : _signInWithGoogle,
          icon: Icons.g_mobiledata_rounded,
          label: 'Continue with Google',
          color: const Color(0xFFDB4437),
        ),
        
        const SizedBox(height: 12),
        
        // Biometric Sign-In Button
        biometricAvailable.when(
          data: (availability) => availability.isFullyAvailable 
            ? _buildSocialButton(
                onPressed: isLoading ? null : _signInWithBiometric,
                icon: Icons.fingerprint_rounded,
                label: 'Use Biometric Authentication',
                color: const Color(0xFF4CAF50),
              )
            : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        
        const SizedBox(height: 20),
        
        // Divider
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[300])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'or',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey[300])),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildEmailForm(bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
            enabled: !isLoading,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (_isRegisterMode && value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
            enabled: !isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isLoading) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isLoading ? null : _signInWithEmail,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1a237e),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  _isRegisterMode ? 'Create Account' : 'Sign In',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          ),
        ),
        
        if (!_isRegisterMode) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: isLoading ? null : () {
              // TODO: Implement forgot password
            },
            child: const Text('Forgot Password?'),
          ),
        ],
        
        // Enable Biometric Button (only show when logged in with email)
        Consumer(
          builder: (context, ref, child) {
            final authService = ref.read(enhancedAuthServiceProvider);
            if (authService.isSignedIn && !_isRegisterMode) {
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton.icon(
                  onPressed: _enableBiometric,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('Enable Biometric Login'),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildToggleMode() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isRegisterMode 
            ? 'Already have an account? ' 
            : 'Don\'t have an account? ',
          style: TextStyle(color: Colors.grey[600]),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _isRegisterMode = !_isRegisterMode;
              _formKey.currentState?.reset();
              _emailController.clear();
              _passwordController.clear();
            });
          },
          child: Text(
            _isRegisterMode ? 'Sign In' : 'Sign Up',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1a237e),
            ),
          ),
        ),
      ],
    );
  }
}
