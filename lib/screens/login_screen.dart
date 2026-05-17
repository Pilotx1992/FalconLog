import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
// Use enhanced auth + biometric providers
import '../services/enhanced_auth_service.dart';
import '../services/navigation_service.dart';
import '../providers/enhanced_biometric_provider.dart';

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
    final maxContentWidth = 520.0;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom; // keyboard
    final isSmallHeight = size.height < 680;
    final baseSpacing = isSmallHeight ? 18.0 : 28.0;

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background (softer premium palette)
          // Upgraded layered gradient background
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surfaceUltraDark,
                  AppColors.surfaceDark,
                  AppColors.surfaceMid,
                  AppColors.surfaceAccent,
                ],
                stops: [0.0, 0.38, 0.72, 1.0],
              ),
            ),
          ),
          // Floating blurred circles (subtle premium depth)
          Positioned(
              top: -60,
              left: -40,
              child: _BlurCircle(
                  size: 210,
                  color: AppColors.brandPrimary.withValues(alpha: 0.18))),
          Positioned(
              bottom: -50,
              right: -30,
              child: _BlurCircle(
                  size: 250,
                  color: AppColors.brandPrimaryLight.withValues(alpha: 0.14))),
          Positioned(
              bottom: size.height * 0.28,
              left: -70,
              child: _BlurCircle(
                  size: 150,
                  color: AppColors.brandPrimary.withValues(alpha: 0.12))),
          // Subtle radial vignette overlay for premium depth
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 1.05,
                  colors: [
                    AppColors.overlayDark(0.0),
                    AppColors.overlayDark(0.8)
                  ],
                  stops: const [0.25, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, baseSpacing, 24,
                    (baseSpacing + viewInsets * 0.4).clamp(24, 120)),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, _) => FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo
                            Hero(
                              tag: 'falcon_logo',
                              child: Container(
                                width: isSmallHeight ? 90 : 118,
                                height: isSmallHeight ? 90 : 118,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.brandPrimary,
                                      AppColors.brandPrimaryLight
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                      color: AppColors.overlayLight(0.12),
                                      width: 1.3),
                                  boxShadow: [
                                    BoxShadow(
                                        color: AppColors.overlayDark(0.55),
                                        blurRadius: 26,
                                        offset: const Offset(0, 16)),
                                    BoxShadow(
                                        color: AppColors.brandPrimaryLight
                                            .withValues(alpha: 0.25),
                                        blurRadius: 38,
                                        spreadRadius: -6),
                                  ],
                                ),
                                // Replaced icon with airplane.png image as requested
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Image.asset(
                                    'assets/airplane.png',
                                    fit: BoxFit.contain,
                                    cacheWidth: 200,
                                    cacheHeight: 200,
                                    filterQuality: FilterQuality.high,
                                    errorBuilder: (c, e, s) => const Icon(
                                      Icons.flight_takeoff_rounded,
                                      size: 58,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: isSmallHeight ? 18 : 26),
                            // Title
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  AppColors.textPrimary,
                                  AppColors.textSecondary
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ).createShader(bounds),
                              child: Text(
                                'FalconLog',
                                style: TextStyle(
                                  fontSize: isSmallHeight ? 38 : 44,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2.0,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(height: isSmallHeight ? 6 : 10),
                            Text(
                              'Welcome Back',
                              style: TextStyle(
                                fontSize: isSmallHeight ? 15 : 17,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textPrimary
                                    .withValues(alpha: 0.82),
                                letterSpacing: 0.55,
                              ),
                            ),
                            SizedBox(height: isSmallHeight ? 26 : 40),
                            // Glass card
                            _GlassCard(
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    _InputField(
                                      label: 'Email',
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      icon: Icons.alternate_email_rounded,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Email required';
                                        }
                                        final r = RegExp(
                                            r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}');
                                        if (!r.hasMatch(v.trim())) {
                                          return 'Invalid email';
                                        }
                                        return null;
                                      },
                                    ),
                                    SizedBox(height: isSmallHeight ? 16 : 22),
                                    _PasswordField(
                                      controller: _passwordController,
                                      obscure: _obscurePassword,
                                      onToggle: () => setState(() =>
                                          _obscurePassword = !_obscurePassword),
                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return 'Password required';
                                        }
                                        if (v.length < 6) {
                                          return 'Min 6 characters';
                                        }
                                        return null;
                                      },
                                    ),
                                    SizedBox(height: isSmallHeight ? 22 : 30),
                                    _PrimaryButton(
                                      text: 'Sign In',
                                      loading: _isLoading,
                                      onPressed:
                                          _isLoading ? null : _handleLogin,
                                    ),
                                    SizedBox(height: isSmallHeight ? 18 : 24),
                                    _DividerLabel(label: 'OR'),
                                    SizedBox(height: isSmallHeight ? 20 : 26),
                                    _GoogleButton(
                                        onPressed: _handleGoogleSignIn),
                                    SizedBox(height: isSmallHeight ? 14 : 18),
                                    Consumer(builder: (context, ref, _) {
                                      final availability = ref
                                          .watch(biometricAvailabilityProvider);
                                      return availability.when(
                                        data: (data) => _BiometricButton(
                                          onPressed: _handleBiometricSignIn,
                                          loading: _isLoading,
                                          available: data.isFullyAvailable,
                                          status: data.statusMessage,
                                        ),
                                        loading: () => const SizedBox.shrink(),
                                        error: (_, __) =>
                                            const SizedBox.shrink(),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: isSmallHeight ? 22 : 30),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style: TextStyle(
                                      color: AppColors.textPrimary
                                          .withValues(alpha: 0.70),
                                      fontSize: 15),
                                ),
                                GestureDetector(
                                  onTap: _handleRegister,
                                  child: const Text(
                                    'Sign Up',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.accentSoftBlue,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallHeight ? 10 : 14),
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
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = ref.read(enhancedAuthServiceProvider);
      await authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        _maybeEnableBiometric(authService);
        // Navigate to main app
        await NavigationService.goToDashboard();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(enhancedAuthServiceProvider);
      final result = await authService.signInWithGoogle();
      if (result != null && mounted) {
        _maybeEnableBiometric(authService);
        await NavigationService.goToDashboard();
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Google sign in failed: ${e.toString()}', Colors.redAccent);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleBiometricSignIn() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(enhancedAuthServiceProvider);
      final result = await authService.signInWithBiometric();
      if (result != null && mounted) {
        await NavigationService.goToDashboard();
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
            e.toString().replaceFirst('Exception: ', ''), Colors.orangeAccent);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleRegister() {
    Navigator.of(context).pushNamed('/register');
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

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ============== Helper Widgets ==============
class _BlurCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _BlurCircle({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(32, 34, 32, 40),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.overlayLight(0.08), width: 1.1),
            gradient: LinearGradient(
              colors: [
                AppColors.overlayLight(0.10),
                AppColors.overlayLight(0.04)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                  color: AppColors.overlayDark(0.35),
                  blurRadius: 42,
                  offset: const Offset(0, 28))
            ],
            borderRadius: BorderRadius.circular(26),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final IconData icon;
  final String? Function(String?)? validator;
  const _InputField(
      {required this.label,
      required this.controller,
      required this.icon,
      this.keyboardType,
      this.validator});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: _fieldDecoration(icon: icon, hint: 'Enter $label'),
        cursorColor: AppColors.accentSoftBlue,
      ),
    ]);
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;
  const _PasswordField(
      {required this.controller,
      required this.obscure,
      required this.onToggle,
      this.validator});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Password',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        obscureText: obscure,
        validator: validator,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration:
            _fieldDecoration(icon: Icons.lock_rounded, hint: 'Enter Password')
                .copyWith(
          suffixIcon: IconButton(
            icon: Icon(
                obscure
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: AppColors.accentAqua),
            onPressed: onToggle,
          ),
        ),
        cursorColor: AppColors.accentSoftBlue,
      ),
    ]);
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final bool loading;
  final VoidCallback? onPressed;
  const _PrimaryButton(
      {required this.text, required this.loading, this.onPressed});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          gradient: loading
              ? LinearGradient(
                  colors: [
                    AppColors.brandPrimary.withValues(alpha: 0.6),
                    AppColors.brandPrimaryLight.withValues(alpha: 0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [AppColors.brandPrimary, AppColors.brandPrimaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: loading
              ? null
              : [
                  BoxShadow(
                    color: AppColors.brandPrimary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
          child: loading
              ? const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                )
              : Text(text,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6)),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(
    {required IconData icon, required String hint}) {
  return InputDecoration(
    prefixIcon: Icon(icon, color: AppColors.accentAqua, size: 22),
    hintText: hint,
    hintStyle:
        TextStyle(color: Colors.white.withValues(alpha: 0.36), fontSize: 14.5),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.06),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide:
          BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.accentSoftBlue, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
    ),
  );
}

class _DividerLabel extends StatelessWidget {
  final String label;
  const _DividerLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
          child: Container(
              height: 1,
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                AppColors.overlayLight(0.05),
                AppColors.overlayLight(0.18)
              ])))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(label,
            style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.8),
                fontSize: 12.5,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600)),
      ),
      Expanded(
          child: Container(
              height: 1,
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                AppColors.overlayLight(0.18),
                AppColors.overlayLight(0.05)
              ])))),
    ]);
  }
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _GoogleButton({required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.overlayLight(0.14), width: 1.3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: AppColors.overlayLight(0.05),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Adapt label for very narrow widths to avoid overflow
            final narrow =
                constraints.maxWidth < 230; // observed overflow around 201px
            final tighter = constraints.maxWidth < 190; // extreme small
            final label = tighter
                ? 'Google'
                : (narrow ? 'Sign in with Google' : 'Continue with Google');
            final fontSize = narrow ? 14.5 : 15.5;
            final gap = narrow ? 8.0 : 12.0;
            return Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/google.png',
                    height: 22,
                    cacheHeight: 44,
                    filterQuality: FilterQuality.medium,
                    width: 22,
                    errorBuilder: (c, e, s) => const Icon(Icons.g_mobiledata,
                        size: 26, color: AppColors.accentSoftBlue),
                  ),
                  SizedBox(width: gap),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BiometricButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool loading;
  final bool available;
  final String status;
  const _BiometricButton(
      {required this.onPressed,
      required this.loading,
      required this.available,
      required this.status});
  @override
  Widget build(BuildContext context) {
    if (!available) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: loading ? null : onPressed,
            icon: const Icon(Icons.fingerprint_rounded,
                color: AppColors.accentMint),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.overlayLight(0.16), width: 1.2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              backgroundColor: AppColors.overlayLight(0.04),
              foregroundColor: Colors.white,
            ),
            label: const Text('Use Biometric',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 6),
        Text(status,
            style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.85),
                fontSize: 11)),
      ],
    );
  }
}
