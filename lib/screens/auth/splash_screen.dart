import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    print('=== SPLASH SCREEN INIT ===');

    // Wait at least 1.8s so the animation is fully visible
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    print('Checking AuthProvider initialization...');
    final auth = context.read<AuthProvider>();

    // Wait for auth to be initialized if not already
    if (!auth.isInitialized) {
      print('AuthProvider not initialized yet, waiting...');
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Verify tokens are still present
    print('AuthProvider.isLoggedIn: ${auth.isLoggedIn}');
    print('AuthProvider.user: ${auth.user != null}');

    // Double-check tokens from shared preferences directly
    final tokensExist = await ApiService.restoreSession();
    print('Tokens exist in SharedPreferences: $tokensExist');

    if (!mounted) return;

    // Restore persisted location for cart and menu
    final cart = context.read<CartProvider>();
    await cart.restoreLocation();
    if (!mounted) return;

    if (cart.selectedLocationId != null) {
      context.read<MenuProvider>().setSelectedLocation(cart.selectedLocationId!);
    }

    // Give a small buffer after auth init
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // Restore normal status bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    // Check if user is logged in
    if (auth.isLoggedIn && auth.user != null) {
      print('User is logged in: ${auth.user!.name}');
      if (cart.selectedLocationId == null) {
        print('No location selected, going to branch selection');
        Navigator.pushReplacementNamed(context, '/branch-selection');
      } else {
        print('Location selected, going to home');
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      print('User not logged in, going to login screen');
      Navigator.pushReplacementNamed(context, '/login');
    }

    print('=== SPLASH SCREEN INIT COMPLETE ===');
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