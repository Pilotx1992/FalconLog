import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_error_mapper.dart';
import '../auth/auth_validators.dart';
import '../services/enhanced_auth_service.dart';
import '../services/navigation_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_snack_bar.dart';
import '../providers/biometric_provider.dart';
import '../widgets/auth/auth_screen_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _animationController, curve: Curves.easeOutCubic));
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || Firebase.apps.isEmpty) return;
      if (FirebaseAuth.instance.currentUser != null) {
        unawaited(NavigationService.goToDashboard());
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final isCompact = authIsCompactLayout(size.height);
    final topPadding = authScrollTopPadding(isCompact);

    return Scaffold(
      body: Stack(
        children: [
          AuthScreenBackground(screenHeight: size.height),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  24,
                  topPadding,
                  24,
                  (topPadding + viewInsets * 0.4).clamp(24, 120),
                ),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: authMaxContentWidth),
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, _) => FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AuthFalconLogo(
                              diameter: authLogoDiameter(isCompact),
                            ),
                            SizedBox(height: isCompact ? 16 : 24),
                            AuthBrandedHeader(
                              subtitle: 'Welcome Back',
                              compact: isCompact,
                            ),
                            SizedBox(height: isCompact ? 24 : 36),
                            AuthGlassCard(
                              child: AutofillGroup(
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      AuthInputField(
                                        label: 'Email',
                                        controller: _emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        icon: Icons.alternate_email_rounded,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.username,
                                          AutofillHints.email,
                                        ],
                                        validator: validateEmail,
                                      ),
                                      SizedBox(
                                          height: authFieldSpacing(isCompact)),
                                      AuthPasswordField(
                                        controller: _passwordController,
                                        obscure: _obscurePassword,
                                        onToggle: () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                        textInputAction: TextInputAction.done,
                                        autofillHints: const [
                                          AutofillHints.password,
                                        ],
                                        onSubmitted: (_) {
                                          if (!_isLoading) {
                                            unawaited(_handleLogin());
                                          }
                                        },
                                        validator: validateLoginPassword,
                                      ),
                                      SizedBox(height: isCompact ? 10 : 14),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: _isLoading
                                              ? null
                                              : _handleForgotPassword,
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: const Text(
                                            'Forgot Password?',
                                            style: TextStyle(
                                              color: AppColors.accentSoftBlue,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                          height:
                                              authFieldSpacing(isCompact) + 4),
                                      AuthPrimaryButton(
                                        text: 'Sign In',
                                        loading: _isLoading,
                                        onPressed:
                                            _isLoading ? null : _handleLogin,
                                      ),
                                      SizedBox(height: isCompact ? 18 : 24),
                                      const AuthDividerLabel(label: 'OR'),
                                      SizedBox(height: isCompact ? 20 : 26),
                                      AuthGoogleButton(
                                        onPressed: _handleGoogleSignIn,
                                        enabled: !_isLoading,
                                      ),
                                      SizedBox(height: isCompact ? 14 : 18),
                                      Consumer(builder: (context, ref, _) {
                                        final availability = ref.watch(
                                            biometricAvailabilityProvider);
                                        return availability.when(
                                          data: (data) => AuthBiometricButton(
                                            onPressed: _handleBiometricSignIn,
                                            loading: _isLoading,
                                            available: data.isFullyAvailable,
                                            status: data.statusMessage,
                                          ),
                                          loading: () =>
                                              const SizedBox.shrink(),
                                          error: (_, __) =>
                                              const SizedBox.shrink(),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: isCompact ? 22 : 30),
                            IgnorePointer(
                              ignoring: _isLoading,
                              child: Opacity(
                                opacity: _isLoading ? 0.5 : 1,
                                child: AuthFooterLink(
                                  prompt: "Don't have an account? ",
                                  actionLabel: 'Sign Up',
                                  onTap: _handleRegister,
                                ),
                              ),
                            ),
                            SizedBox(height: isCompact ? 10 : 14),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(enhancedAuthServiceProvider);
      await authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      await _maybeEnableBiometric(authService);
      if (!mounted) return;
      await NavigationService.goToDashboard();
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, message: authErrorMessage(e), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(enhancedAuthServiceProvider);
      final result = await authService.signInWithGoogle();
      if (result != null && mounted) {
        await _maybeEnableBiometric(authService);
        if (!mounted) return;
        await NavigationService.goToDashboard();
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, message: authErrorMessage(e), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleBiometricSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(enhancedAuthServiceProvider);
      await authService.ensureInitialized();
      await authService.signInWithBiometric();
      if (mounted && authService.isSignedIn) {
        await NavigationService.goToDashboard();
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, message: authErrorMessage(e), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleRegister() {
    if (_isLoading) return;
    Navigator.of(context).pushNamed('/register');
  }

  void _handleForgotPassword() {
    if (_isLoading) return;
    Navigator.of(context).pushNamed('/forgot-password');
  }

  Future<void> _maybeEnableBiometric(EnhancedAuthService service) async {
    try {
      final already = await service.isBiometricEnabled();
      if (already) return;
      final available = await service.isBiometricAvailable();
      if (!available) return;
      await service.enableBiometricAuth();
      // Silent success; next launch can use biometric
    } catch (e) {
      debugPrint('Biometric auto-enable skipped: $e');
    }
  }
}
