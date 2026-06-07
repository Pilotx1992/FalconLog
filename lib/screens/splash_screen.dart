import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/navigation_service.dart';
import '../utils/responsive_layout.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  bool _hasNavigatedAway = false;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();

    Future.microtask(() => HapticFeedback.mediumImpact());

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    _splashTimer = Timer(const Duration(seconds: 4), _exitSplash);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      NavigationService.routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    NavigationService.routeObserver.unsubscribe(this);
    _controller.dispose();
    super.dispose();
  }

  /// If the user backs into splash, leave immediately (timer already ran).
  @override
  void didPopNext() {
    _exitSplash();
  }

  void _exitSplash() {
    if (_hasNavigatedAway || !mounted) return;
    _hasNavigatedAway = true;
    _splashTimer?.cancel();

    HapticFeedback.lightImpact();
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final destination = isLoggedIn ? '/home' : '/login';

    Navigator.of(context).pushNamedAndRemoveUntil(
      destination,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 19, 89, 155),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = isCompactHeight(constraints.maxHeight);
              final logoSize = compact ? 48.0 : 60.0;
              final titleSize = compact ? 28.0 : 34.0;

              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: FadeTransition(
                      opacity: _fade,
                      child: ScaleTransition(
                        scale: _scale,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/airplane.png',
                                  width: logoSize,
                                  height: logoSize,
                                  fit: BoxFit.contain,
                                ),
                                SizedBox(width: compact ? 10 : 14),
                                Text(
                                  'FalconLog',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: compact ? 8 : 14),
                            const Text(
                              'Get ready for',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: compact ? 16 : 36),
                            SizedBox(
                              width: 160,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  minHeight: 6,
                                  backgroundColor: Colors.white10,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.amber.shade400,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: compact ? 10 : 16),
                            const Text(
                              'Preparing for Takeoff...',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
