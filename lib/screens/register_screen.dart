import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_error_mapper.dart';
import '../auth/auth_validators.dart';
import '../providers/auth_provider.dart';
import '../services/navigation_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_snack_bar.dart';
import '../widgets/auth/auth_screen_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    ref.read(authLoadingProvider.notifier).state = true;

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.registerWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );

      if (!mounted) return;
      if (result?.user != null) {
        // Firebase signs the user in after createUserWithEmailAndPassword.
        await NavigationService.goToDashboard();
      }
    } catch (e) {
      if (mounted) {
        _showSnack(authErrorMessage(e), AppColors.danger);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ref.read(authLoadingProvider.notifier).state = false;
      }
    }
  }

  void _goToLogin() {
    if (_isSubmitting) return;
    Navigator.of(context).maybePop();
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: AppSnackBar.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider) || _isSubmitting;
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
                              subtitle: 'Create your pilot account',
                              compact: isCompact,
                            ),
                            SizedBox(height: isCompact ? 24 : 32),
                            AuthGlassCard(
                              child: AutofillGroup(
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Create Account',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: isCompact ? 20 : 22,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.4,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      SizedBox(height: isCompact ? 18 : 24),
                                      AuthInputField(
                                        label: 'Full Name',
                                        controller: _nameController,
                                        icon: Icons.person_outline_rounded,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.name
                                        ],
                                        validator: validateDisplayName,
                                      ),
                                      SizedBox(
                                          height: authFieldSpacing(isCompact)),
                                      AuthInputField(
                                        label: 'Email',
                                        controller: _emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        icon: Icons.alternate_email_rounded,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.email
                                        ],
                                        validator: validateEmail,
                                      ),
                                      SizedBox(
                                          height: authFieldSpacing(isCompact)),
                                      AuthPasswordField(
                                        label: 'Password',
                                        hint: 'Enter Password',
                                        controller: _passwordController,
                                        obscure: _obscurePassword,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.newPassword,
                                        ],
                                        onToggle: () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                        validator: validateRegisterPassword,
                                      ),
                                      SizedBox(
                                          height: authFieldSpacing(isCompact)),
                                      AuthPasswordField(
                                        label: 'Confirm Password',
                                        hint: 'Confirm Password',
                                        controller: _confirmPasswordController,
                                        obscure: _obscureConfirmPassword,
                                        textInputAction: TextInputAction.done,
                                        autofillHints: const [
                                          AutofillHints.newPassword,
                                        ],
                                        onSubmitted: (_) {
                                          if (!isLoading) {
                                            unawaited(_register());
                                          }
                                        },
                                        onToggle: () => setState(
                                          () => _obscureConfirmPassword =
                                              !_obscureConfirmPassword,
                                        ),
                                        validator: (value) =>
                                            validateConfirmPassword(
                                          value,
                                          _passwordController.text,
                                        ),
                                      ),
                                      SizedBox(
                                          height:
                                              authFieldSpacing(isCompact) + 8),
                                      AuthPrimaryButton(
                                        text: 'Create Account',
                                        loading: isLoading,
                                        onPressed: isLoading ? null : _register,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: isCompact ? 18 : 26),
                            IgnorePointer(
                              ignoring: isLoading,
                              child: Opacity(
                                opacity: isLoading ? 0.5 : 1,
                                child: AuthFooterLink(
                                  prompt: 'Already have an account? ',
                                  actionLabel: 'Sign In',
                                  onTap: _goToLogin,
                                ),
                              ),
                            ),
                            SizedBox(height: isCompact ? 8 : 12),
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
}
