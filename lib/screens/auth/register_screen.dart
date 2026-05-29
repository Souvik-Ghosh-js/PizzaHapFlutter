import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../config/app_config.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_loader.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  // Step 0 = name, Step 1 = email + mobile, Step 2 = OTP
  int _step = 0;
  final _nameCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _otpCtrl    = TextEditingController();
  final _nameFocus  = FocusNode();
  final _emailFocus = FocusNode();

  String? _nameError;
  String? _emailError;
  bool _loading = false;
  int _resendSeconds = 0;

  late AnimationController _pageCtrl;
  late Animation<double> _pageFade;
  late Animation<Offset> _pageSlide;

  @override
  void initState() {
    super.initState();
    _pageCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _pageFade = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));
    _pageCtrl.forward();
    // Pre-fill from args if coming from login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        _emailCtrl.text = args['email'] ?? '';
        if (args['otp'] != null) _otpCtrl.text = args['otp'];
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _mobileCtrl.dispose(); _otpCtrl.dispose();
    _nameFocus.dispose(); _emailFocus.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _animateNextStep() {
    _pageCtrl.reset();
    _pageCtrl.forward();
  }

  void _nextStep() {
    if (_step == 0) {
      if (_nameCtrl.text.trim().isEmpty) {
        setState(() => _nameError = 'Please enter your name');
        return;
      }
      if (_nameCtrl.text.trim().length < 2) {
        setState(() => _nameError = 'Name must be at least 2 characters');
        return;
      }
      setState(() { _nameError = null; _step = 1; });
      _animateNextStep();
      Future.delayed(const Duration(milliseconds: 200), () => _emailFocus.requestFocus());
    } else if (_step == 1) {
      final email = _emailCtrl.text.trim();
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
        setState(() => _emailError = 'Enter a valid email address');
        return;
      }
      setState(() => _emailError = null);
      _sendOtp();
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step -= 1);
      _animateNextStep();
    } else {
      Navigator.pop(context);
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

  Future<void> _sendOtp() async {
    setState(() => _loading = true);
    AppLoader.show(context, message: 'Sending OTP...');
    final auth = context.read<AuthProvider>();
    final ok = await auth.sendOtp(_emailCtrl.text.trim());
    AppLoader.hide();
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      setState(() => _step = 2);
      _animateNextStep();
      _startResendTimer();
      AppToast.success(context, 'OTP sent! Check your inbox');
    } else {
      AppToast.error(context, auth.error ?? 'Failed to send OTP');
    }
  }

  Future<void> _register(String otp) async {
    setState(() => _loading = true);
    AppLoader.show(context, message: 'Creating account...');
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      _nameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      otp,
      mobile: _mobileCtrl.text.trim().isEmpty ? null : _mobileCtrl.text.trim(),
    );
    AppLoader.hide();
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.pushReplacementNamed(context, '/branch-selection');
    } else {
      AppToast.error(context, auth.error ?? 'Registration failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _prevStep();
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
                // Header gradient
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    height: size.height * 0.38,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(AppColors.primaryDark), Color(AppColors.primary)],
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: -40, right: -40,
                child: Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              SafeArea(
                child: FadeTransition(
                  opacity: _pageFade,
                  child: SlideTransition(
                    position: _pageSlide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          // Back button
                          GestureDetector(
                            onTap: _prevStep,
                            child: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                          SizedBox(height: size.height * 0.07),
                          // Logo container with white background, padding and border radius (like login screen)
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
                                  color: Colors.black.withValues(alpha: 0.09),
                                  blurRadius: 28,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Step indicator
                                _StepIndicator(step: _step, total: 3),
                                const SizedBox(height: 22),
                                if (_step == 0) _buildNameStep(),
                                if (_step == 1) _buildEmailStep(),
                                if (_step == 2) _buildOtpStep(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Already have an account?',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pushReplacementNamed(context, '/login'),
                                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                                  child: const Text('Sign In',
                                      style: TextStyle(color: Color(AppColors.primary),
                                          fontWeight: FontWeight.w800, fontSize: 14)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text('Developed by GOBT',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
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

  // ─── STEP 0: Name ──────────────────────────────────────────────
  Widget _buildNameStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("What's your name?",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
              color: Color(AppColors.textPrimary))),
      const SizedBox(height: 4),
      Text("We'll use this on your orders",
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
      const SizedBox(height: 24),
      TextField(
        controller: _nameCtrl,
        focusNode: _nameFocus,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => _nextStep(),
        autofocus: true,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: 'Full Name',
          hintText: 'e.g. Arjun Sharma',
          prefixIcon: _prefixIcon(Icons.person_outline_rounded),
          errorText: _nameError,
        ),
      ),
      const SizedBox(height: 24),
      _nextButton('Continue', _nextStep, _loading),
    ],
  );

  // ─── STEP 1: Email + Mobile ─────────────────────────────────────
  Widget _buildEmailStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Hi ${_nameCtrl.text.trim().split(' ').first}!',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
              color: Color(AppColors.textPrimary))),
      const SizedBox(height: 4),
      Text('Enter your email to get started',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
      const SizedBox(height: 24),
      TextField(
        controller: _emailCtrl,
        focusNode: _emailFocus,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: 'Email Address',
          hintText: 'you@example.com',
          prefixIcon: _prefixIcon(Icons.email_outlined),
          errorText: _emailError,
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _mobileCtrl,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _nextStep(),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: 'Mobile Number (optional)',
          hintText: '9876543210',
          prefixIcon: _prefixIcon(Icons.phone_outlined),
          prefixText: '+91  ',
        ),
      ),
      const SizedBox(height: 24),
      _nextButton('Send OTP', _nextStep, _loading),
    ],
  );

  // ─── STEP 2: OTP ───────────────────────────────────────────────
  Widget _buildOtpStep() => Column(
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
              style: const TextStyle(fontWeight: FontWeight.w700,
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
              border: Border.all(color: const Color(AppColors.primary), width: 2),
              boxShadow: [
                BoxShadow(color: const Color(AppColors.primary).withValues(alpha: 0.12), blurRadius: 10),
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
              border: Border.all(color: const Color(AppColors.primary).withValues(alpha: 0.35), width: 1.5),
            ),
          ),
          onCompleted: _loading ? null : _register,
        ),
      ),
      const SizedBox(height: 24),
      _nextButton('Create Account', () {
        if (_otpCtrl.text.length < 6) {
          AppToast.error(context, 'Enter the complete 6-digit OTP');
          return;
        }
        _register(_otpCtrl.text.trim());
      }, _loading),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: () { setState(() { _step = 1; _otpCtrl.clear(); }); _animateNextStep(); },
            icon: const Icon(Icons.arrow_back_rounded, size: 14),
            label: const Text('Change email'),
            style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade500,
                padding: EdgeInsets.zero),
          ),
          TextButton(
            onPressed: _loading || _resendSeconds > 0 ? null : _sendOtp,
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

  Widget _prefixIcon(IconData icon) => Container(
    margin: const EdgeInsets.all(10),
    width: 38, height: 38,
    decoration: BoxDecoration(
      color: const Color(AppColors.primary).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, size: 18, color: const Color(AppColors.primary)),
  );

  Widget _nextButton(String label, VoidCallback onTap, bool loading) => SizedBox(
    width: double.infinity,
    height: 54,
    child: ElevatedButton(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(AppColors.primary),
        disabledBackgroundColor: const Color(AppColors.primary).withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: loading
          ? const SizedBox(width: 22, height: 22,
          child: PizzaSpinner(size: 24, color: Colors.white))
          : Text(label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
              color: Colors.white)),
    ),
  );
}

// ─── STEP INDICATOR ──────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int step;
  final int total;
  const _StepIndicator({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i == step;
        final done = i < step;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: done
                  ? const Color(AppColors.primary)
                  : active
                  ? const Color(AppColors.primary).withValues(alpha: 0.4)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
            child: active
                ? ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: null,
                backgroundColor: const Color(AppColors.primary).withValues(alpha: 0.2),
                color: const Color(AppColors.primary),
              ),
            )
                : null,
          ),
        );
      }),
    );
  }
}