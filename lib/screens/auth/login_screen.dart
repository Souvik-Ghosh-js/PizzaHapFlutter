import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import '../../providers/providers.dart';
import '../../config/app_config.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_loader.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _otpSent = false;
  bool _sending = false;
  bool _verifying = false;
  String? _emailError;
  int _resendSeconds = 0;

  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _animateIn() {
    _fadeCtrl.reset();
    _slideCtrl.reset();
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  bool _isValidEmail(String e) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e.trim());

  Future<void> _sendOtp() async {
    setState(() => _emailError = null);
    if (!_isValidEmail(_emailCtrl.text)) {
      setState(() => _emailError = 'Enter a valid email address');
      return;
    }
    setState(() => _sending = true);
    AppLoader.show(context, message: 'Sending OTP...');
    final auth = context.read<AuthProvider>();
    final ok = await auth.sendOtp(_emailCtrl.text.trim());
    AppLoader.hide();
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      setState(() { _otpSent = true; });
      _animateIn();
      _startResendTimer();
      AppToast.success(context, 'OTP sent! Check your inbox');
    } else {
      AppToast.error(context, auth.error ?? 'Failed to send OTP');
    }
  }

  void _startResendTimer() {
    setState(() => _resendSeconds = 30);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendSeconds--);
      return _resendSeconds > 0;
    });
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.length < 6) {  // Changed from 4 to 6
      AppToast.error(context, 'Enter the complete 6-digit OTP');
      return;
    }
    setState(() => _verifying = true);
    AppLoader.show(context, message: 'Verifying...');
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_emailCtrl.text.trim(), _otpCtrl.text.trim());
    AppLoader.hide();
    if (!mounted) return;
    setState(() => _verifying = false);
    if (ok) {
      final cart = context.read<CartProvider>();
      if (cart.selectedLocationId == null) {
        Navigator.pushReplacementNamed(context, '/branch-selection');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      final err = auth.error ?? '';
      if (err.toLowerCase().contains('not found') ||
          err.toLowerCase().contains('not registered')) {
        Navigator.pushReplacementNamed(context, '/register',
            arguments: {'email': _emailCtrl.text.trim(), 'otp': _otpCtrl.text.trim()});
      } else {
        AppToast.error(context, err.isNotEmpty ? err : 'Invalid OTP');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: !_otpSent,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_otpSent) {
          setState(() {
            _otpSent = false;
            _otpCtrl.clear();
          });
          _animateIn();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(AppColors.background),
        resizeToAvoidBottomInset: true,
        body: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: size.height),
            child: Stack(
              children: [
                // Top red half
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    height: size.height * 0.45,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(AppColors.primaryDark), Color(AppColors.primary)],
                      ),
                    ),
                  ),
                ),
              // Decorative circles on header
              Positioned(
                top: -50, right: -50,
                child: Container(
                  width: 180, height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ),
              Positioned(
                top: 60, left: -30,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              // Content
              SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: size.height * 0.07),
                          // Logo container with white background, padding and border radius
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(20), // Adds spacing around logo
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.22),
                                    blurRadius: 28,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Container(
                                width: 160,
                                height: 110,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.local_pizza_rounded, size: 60,
                                          color: Color(AppColors.primary)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 30,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: _otpSent ? _buildOtpStep() : _buildEmailStep(),
                          ),
                          const SizedBox(height: 28),
                          // Sign up link
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("Don't have an account?",
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pushNamed(context, '/register'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  child: const Text('Sign Up',
                                      style: TextStyle(
                                          color: Color(AppColors.primary),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text('Developed by GOBT',
                                style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 11)),
                          ),
                          SizedBox(height: 24 + bottomPad),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),);
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Welcome back',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                color: Color(AppColors.textPrimary))),
        const SizedBox(height: 4),
        Text('Sign in to continue ordering',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        const SizedBox(height: 28),
        // Email field
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _sendOtp(),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: 'Email Address',
            hintText: 'you@example.com',
            prefixIcon: Container(
              margin: const EdgeInsets.all(10),
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: const Color(AppColors.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.email_outlined,
                  size: 18, color: Color(AppColors.primary)),
            ),
            errorText: _emailError,
          ),
        ),
        const SizedBox(height: 24),
        // CTA button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _sending ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _sending
                ? const SizedBox(width: 22, height: 22,
                child: PizzaSpinner(size: 24, color: Colors.white))
                : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Get OTP',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                        color: Colors.white)),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Verify your email',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                color: Color(AppColors.textPrimary))),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            children: [
              const TextSpan(text: 'Code sent to '),
              TextSpan(
                text: _emailCtrl.text.trim(),
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(AppColors.textPrimary)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Center(
          child: Pinput(
            controller: _otpCtrl,
            length: 6,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            defaultPinTheme: PinTheme(
              width: 46, height: 52,
              textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                  color: Color(AppColors.textPrimary)),
              decoration: BoxDecoration(
                color: const Color(AppColors.background),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200, width: 1.5),
              ),
            ),
            focusedPinTheme: PinTheme(
              width: 46, height: 52,
              textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                  color: Color(AppColors.primary)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(AppColors.primary), width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(AppColors.primary).withValues(alpha: 0.15),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
            submittedPinTheme: PinTheme(
              width: 46, height: 52,
              textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                  color: Color(AppColors.primary)),
              decoration: BoxDecoration(
                color: const Color(AppColors.primary).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(AppColors.primary).withValues(alpha: 0.4), width: 1.5),
              ),
            ),
            onCompleted: (_) => _verifyOtp(),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _verifying ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _verifying
                ? const SizedBox(width: 22, height: 22,
                child: PizzaSpinner(size: 24, color: Colors.white))
                : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Verify & Sign In',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() { _otpSent = false; _otpCtrl.clear(); });
                _animateIn();
              },
              icon: const Icon(Icons.arrow_back_rounded, size: 14),
              label: const Text('Change email'),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade500,
                  padding: EdgeInsets.zero),
            ),
            TextButton(
              onPressed: _sending || _resendSeconds > 0 ? null : () async {
                final auth = context.read<AuthProvider>();
                await auth.resendOtp(_emailCtrl.text.trim());
                if (mounted) {
                  AppToast.success(context, 'OTP resent!');
                  _startResendTimer();
                }
              },
              style: TextButton.styleFrom(
                  foregroundColor: const Color(AppColors.primary),
                  padding: EdgeInsets.zero),
              child: Text(
                _resendSeconds > 0 ? 'Resend in ${_resendSeconds}s' : 'Resend OTP',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }
}