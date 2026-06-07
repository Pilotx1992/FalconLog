import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../utils/responsive_layout.dart';

/// Max width for auth form content on large screens.
const double authMaxContentWidth = 520;

/// Screens shorter than this use compact spacing and smaller logo/type.
const double authCompactHeightBreakpoint = kCompactHeightBreakpoint;

/// Hero tag for the shared logo between login and register (one route at a time).
const String authFalconLogoHeroTag = 'falcon_logo';

bool authIsCompactLayout(double screenHeight) =>
    screenHeight < authCompactHeightBreakpoint;

/// Shared logo size so login/register Hero transitions stay proportional.
double authLogoDiameter(bool compact) => compact ? 86 : 112;

/// Vertical gap between auth form fields (login and register).
double authFieldSpacing(bool compact) => compact ? 14 : 20;

/// Top scroll padding inside the auth safe area.
double authScrollTopPadding(bool compact) => compact ? 16 : 26;

/// Layered gradient, accent circles, and vignette behind auth screens.
class AuthScreenBackground extends StatelessWidget {
  const AuthScreenBackground({super.key, required this.screenHeight});

  final double screenHeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
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
          child: SizedBox.expand(),
        ),
        Positioned(
          top: -60,
          left: -40,
          child: AuthAccentCircle(
            size: 210,
            color: AppColors.brandPrimary.withValues(alpha: 0.18),
          ),
        ),
        Positioned(
          bottom: -50,
          right: -30,
          child: AuthAccentCircle(
            size: 250,
            color: AppColors.brandPrimaryLight.withValues(alpha: 0.14),
          ),
        ),
        Positioned(
          bottom: screenHeight * 0.28,
          left: -70,
          child: AuthAccentCircle(
            size: 150,
            color: AppColors.brandPrimary.withValues(alpha: 0.12),
          ),
        ),
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 1.05,
                colors: [
                  AppColors.overlayDark(0.0),
                  AppColors.overlayDark(0.8),
                ],
                stops: const [0.25, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Soft colored circle used in the auth background (not blurred itself).
class AuthAccentCircle extends StatelessWidget {
  const AuthAccentCircle({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// Hero logo shared between login and register.
class AuthFalconLogo extends StatelessWidget {
  const AuthFalconLogo({super.key, required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    final iconSize = diameter * 0.5;
    return Hero(
      tag: authFalconLogoHeroTag,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.brandPrimary, AppColors.brandPrimaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: AppColors.overlayLight(0.12),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.overlayDark(0.55),
                blurRadius: 26,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: AppColors.brandPrimaryLight.withValues(alpha: 0.25),
                blurRadius: 38,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Image.asset(
              'assets/airplane.png',
              fit: BoxFit.contain,
              cacheWidth: 200,
              cacheHeight: 200,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.flight_takeoff_rounded,
                size: iconSize,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// FalconLog title + subtitle under the logo.
class AuthBrandedHeader extends StatelessWidget {
  const AuthBrandedHeader({
    super.key,
    required this.subtitle,
    required this.compact,
  });

  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.textPrimary, AppColors.textSecondary],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: Text(
            'FalconLog',
            style: TextStyle(
              fontSize: compact ? 34 : 42,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: compact ? 6 : 10),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: compact ? 14 : 16,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary.withValues(alpha: 0.82),
            letterSpacing: 0.55,
          ),
        ),
      ],
    );
  }
}

/// Frosted glass container for auth forms.
class AuthGlassCard extends StatelessWidget {
  const AuthGlassCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(32, 34, 32, 38),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.overlayLight(0.08),
              width: 1.1,
            ),
            gradient: LinearGradient(
              colors: [
                AppColors.overlayLight(0.10),
                AppColors.overlayLight(0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.overlayDark(0.35),
                blurRadius: 42,
                offset: const Offset(0, 28),
              ),
            ],
            borderRadius: BorderRadius.circular(26),
          ),
          child: child,
        ),
      ),
    );
  }
}

class AuthInputField extends StatelessWidget {
  const AuthInputField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.autofillHints,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final IconData icon;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: authFieldDecoration(icon: icon, hint: 'Enter $label'),
          cursorColor: AppColors.accentSoftBlue,
        ),
      ],
    );
  }
}

class AuthPasswordField extends StatelessWidget {
  const AuthPasswordField({
    super.key,
    this.label = 'Password',
    this.hint = 'Enter Password',
    required this.controller,
    required this.obscure,
    required this.onToggle,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.validator,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: authFieldDecoration(
            icon: Icons.lock_rounded,
            hint: hint,
          ).copyWith(
            suffixIcon: Semantics(
              button: true,
              label: obscure ? 'Show password' : 'Hide password',
              child: IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.accentAqua,
                ),
                tooltip: obscure ? 'Show password' : 'Hide password',
                onPressed: onToggle,
              ),
            ),
          ),
          cursorColor: AppColors.accentSoftBlue,
        ),
      ],
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.text,
    required this.loading,
    this.onPressed,
  });

  final String text;
  final bool loading;
  final VoidCallback? onPressed;

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
                  colors: [
                    AppColors.brandPrimary,
                    AppColors.brandPrimaryLight,
                  ],
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
          child: loading
              ? const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  text,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
        ),
      ),
    );
  }
}

class AuthDividerLabel extends StatelessWidget {
  const AuthDividerLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.overlayLight(0.05),
                  AppColors.overlayLight(0.18),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.8),
              fontSize: 12.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.overlayLight(0.18),
                  AppColors.overlayLight(0.05),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthGoogleButton extends StatelessWidget {
  const AuthGoogleButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
  });

  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.overlayLight(0.14), width: 1.3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: AppColors.overlayLight(0.05),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 230;
            final tighter = constraints.maxWidth < 190;
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
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.g_mobiledata,
                      size: 26,
                      color: AppColors.accentSoftBlue,
                    ),
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

class AuthBiometricButton extends StatelessWidget {
  const AuthBiometricButton({
    super.key,
    required this.onPressed,
    required this.loading,
    required this.available,
    required this.status,
  });

  final VoidCallback onPressed;
  final bool loading;
  final bool available;
  final String status;

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
            icon: const Icon(
              Icons.fingerprint_rounded,
              color: AppColors.accentMint,
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.overlayLight(0.16), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              backgroundColor: AppColors.overlayLight(0.04),
              foregroundColor: Colors.white,
            ),
            label: const Text(
              'Use Biometric',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          status,
          style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.85),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// Footer prompt with tappable action (e.g. Sign In / Sign Up).
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.actionLabel,
    required this.onTap,
  });

  final String prompt;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: TextStyle(
            color: AppColors.textPrimary.withValues(alpha: 0.70),
            fontSize: 15,
          ),
        ),
        Semantics(
          button: true,
          label: actionLabel,
          child: GestureDetector(
            onTap: onTap,
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.accentSoftBlue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

InputDecoration authFieldDecoration({
  required IconData icon,
  required String hint,
}) {
  return InputDecoration(
    prefixIcon: Icon(icon, color: AppColors.accentAqua, size: 22),
    hintText: hint,
    hintStyle: TextStyle(
      color: Colors.white.withValues(alpha: 0.36),
      fontSize: 14.5,
    ),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.06),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: Colors.white.withValues(alpha: 0.12),
        width: 1.2,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(
        color: AppColors.accentSoftBlue,
        width: 1.6,
      ),
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
