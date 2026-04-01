import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _logoController;

  late Animation<double> _bgOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  @override
  void initState() {
    super.initState();
    // Force status bar dark icons on white bg
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    _bgController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _logoController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    _bgOpacity = CurvedAnimation(parent: _bgController, curve: Curves.easeOut);

    _logoScale = Tween<double>(begin: 0.25, end: 1.0).animate(
        CurvedAnimation(parent: _logoController, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0, 0.35, curve: Curves.easeOut)));

    _runSequence();
    _init();
  }

  Future<void> _runSequence() async {
    if (!mounted) return;
    // BG fades in instantly to cover the native splash
    await _bgController.forward();
    if (!mounted) return;
    // Logo bounces in
    _logoController.forward();
  }

  Future<void> _init() async {
    // Wait at least 1.8s so the animation is fully visible
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    await context.read<AuthProvider>().init();
    if (!mounted) return;
    // Give a small buffer after auth init
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // Restore normal status bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) {
      final cart = context.read<CartProvider>();
      if (cart.selectedLocationId == null) {
        Navigator.pushReplacementNamed(context, '/branch-selection');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _bgOpacity,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.white,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: AnimatedBuilder(
                animation: _logoController,
                builder: (_, child) => Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: child,
                  ),
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


