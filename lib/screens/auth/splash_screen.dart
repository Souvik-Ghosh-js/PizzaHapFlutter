import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';

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
    
    // 1. Remove native splash screen as soon as Flutter renders its first frame
    FlutterNativeSplash.remove();

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
    // BG fades in instantly to cover the native splash transition
    await _bgController.forward();
    if (!mounted) return;
    // Logo bounces in
    _logoController.forward();
  }

  Future<void> _init() async {
    debugPrint('=== SPLASH SCREEN INIT ===');

    try {
      // 1. Wait at least 1.8s so the animation is fully visible
      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted) return;

      // 2. Wait for AuthProvider to finish its async init (ApiService.init + Session restore)
      final auth = context.read<AuthProvider>();
      
      int waitMs = 0;
      const maxWaitMs = 5000; // 5 seconds max wait
      while (!auth.isInitialized && waitMs < maxWaitMs) {
        debugPrint('Waiting for AuthProvider to initialize ($waitMs ms)...');
        await Future.delayed(const Duration(milliseconds: 250));
        waitMs += 250;
      }

      if (!mounted) return;

      // 3. Restore persisted location
      final cart = context.read<CartProvider>();
      await cart.restoreLocation().timeout(const Duration(seconds: 2), onTimeout: () => null);
      
      if (cart.selectedLocationId != null) {
        context.read<MenuProvider>().setSelectedLocation(cart.selectedLocationId!);
      }

      // 4. Final transition logic — tokens exist means user is logged in,
      // even if the profile fetch failed due to a network error.
      if (auth.isLoggedIn) {
        if (cart.selectedLocationId == null) {
          Navigator.pushReplacementNamed(context, '/branch-selection');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      debugPrint('SplashScreen Error: $e');
      // On any critical failure, fallback to login
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }

    debugPrint('=== SPLASH SCREEN INIT COMPLETE ===');
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
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
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
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.local_pizza_rounded,
                    size: 80,
                    color: Color(0xFF991515),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}