import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_config.dart';

class OrderConfirmScreen extends StatefulWidget {
  final int orderId;
  final String orderNumber;
  final double total;
  final int coinsRedeemed;

  const OrderConfirmScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.total,
    this.coinsRedeemed = 0,
  });

  @override
  State<OrderConfirmScreen> createState() => _OrderConfirmScreenState();
}

class _OrderConfirmScreenState extends State<OrderConfirmScreen>
    with TickerProviderStateMixin {
  late AnimationController _circleController;
  late AnimationController _contentController;
  late AnimationController _pulseController;

  late Animation<double> _circleScale;
  late Animation<double> _circleFade;
  late Animation<double> _checkScale;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _circleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _contentController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);

    _circleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _circleController, curve: Curves.elasticOut));
    _circleFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _circleController, curve: const Interval(0, 0.4)));
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _circleController,
        curve: const Interval(0.4, 1.0, curve: Curves.elasticOut)));

    _contentFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _contentController, curve: Curves.easeOut));
    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _contentController, curve: Curves.easeOutCubic));

    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    HapticFeedback.mediumImpact();
    _circleController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _contentController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _circleController.dispose();
    _contentController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
      },
      child: Scaffold(
        backgroundColor: const Color(AppColors.background),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () =>
                Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Success icon
                AnimatedBuilder(
                  animation: _circleController,
                  builder: (_, __) => Opacity(
                    opacity: _circleFade.value,
                    child: ScaleTransition(
                      scale: _pulse,
                      child: Transform.scale(
                        scale: _circleScale.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(AppColors.success),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(AppColors.success)
                                    .withValues(alpha: 0.35),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Transform.scale(
                            scale: _checkScale.value,
                            child: const Icon(Icons.check_rounded,
                                color: Colors.white, size: 60),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Content
                FadeTransition(
                  opacity: _contentFade,
                  child: SlideTransition(
                    position: _contentSlide,
                    child: Column(
                      children: [
                        const Text(
                          'Order Placed!',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Color(AppColors.textPrimary)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your order has been confirmed.',
                          style: TextStyle(
                              fontSize: 15, color: Colors.grey.shade500),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        // Order details card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: Column(children: [
                            _detailRow(Icons.receipt_outlined, 'Order Number',
                                '#${widget.orderNumber}'),
                            Divider(color: Colors.grey.shade100, height: 20),
                            _detailRow(
                                Icons.currency_rupee_rounded,
                                'Total Amount',
                                '₹${widget.total.toStringAsFixed(0)}'),
                            if (widget.coinsRedeemed > 0) ...[
                              Divider(color: Colors.grey.shade100, height: 20),
                              _detailRow(Icons.stars_rounded,
                                  'Coins Redeemed', '${widget.coinsRedeemed}',
                                  valueColor: const Color(AppColors.coins)),
                            ],
                          ]),
                        ),
                        const SizedBox(height: 16),
                        // Estimated time banner
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(AppColors.primary)
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: const Color(AppColors.primary)
                                    .withValues(alpha: 0.15)),
                          ),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time_rounded,
                                    color: Color(AppColors.primary), size: 18),
                                SizedBox(width: 10),
                                Text('Estimated delivery: 30-45 mins',
                                    style: TextStyle(
                                        color: Color(AppColors.primary),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                              ]),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // Buttons
                FadeTransition(
                  opacity: _contentFade,
                  child: Column(children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context, '/order-detail', (r) => false,
                          arguments: widget.orderId),
                      icon: const Icon(Icons.track_changes_rounded, size: 18),
                      label: const Text('Track Order',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context, '/home', (r) => false),
                      icon: const Icon(Icons.home_rounded, size: 18),
                      label: const Text('Back to Home',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52)),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value,
          {Color? valueColor}) =>
      Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: const Color(AppColors.primary).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: const Color(AppColors.primary)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13))),
        Text(value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: valueColor ?? const Color(AppColors.textPrimary),
            )),
      ]);
}
