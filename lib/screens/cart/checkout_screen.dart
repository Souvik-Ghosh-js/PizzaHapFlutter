import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../config/app_config.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_loader.dart';
import '../../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _deliveryType = 'delivery';
  String _paymentMethod = 'cash_on_delivery';
  bool _placingOrder = false;
  bool _useCoins = false;
  bool _addressInitialized = false;

  final _houseCtrl = TextEditingController();
  final _townCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFromUser());
  }

  /// Pull address + coin balance from the user profile (live from server)
  void _initFromUser() {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    // Refresh user in background to get most updated coins
    auth.refreshUser();

    // Pre-fill address from profile — only on first open
    if (!_addressInitialized) {
      _houseCtrl.text = user.addressHouse ?? '';
      _townCtrl.text = user.addressTown ?? '';
      _stateCtrl.text = user.addressState ?? '';
      _pincodeCtrl.text = user.addressPincode ?? '';
      _addressInitialized = true;
    }
    // Set available coins in cart provider
    context.read<CartProvider>().setAvailableCoins(user.coinBalance);
  }

  @override
  void dispose() {
    _houseCtrl.dispose();
    _townCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  bool get _hasAddress =>
      _houseCtrl.text.trim().isNotEmpty &&
      _townCtrl.text.trim().isNotEmpty &&
      _pincodeCtrl.text.trim().isNotEmpty;

  Future<void> _placeOrder() async {
    final cart = context.read<CartProvider>();
    if (cart.selectedLocationId == null) {
      AppToast.error(context, 'No branch selected.');
      return;
    }
    if (_deliveryType == 'delivery' && !_hasAddress) {
      AppToast.error(context, 'Please fill in your delivery address');
      return;
    }

    setState(() => _placingOrder = true);
    AppLoader.show(context, message: 'Placing your order...');

    // Auto-save address to profile so it persists for next order
    final user = context.read<AuthProvider>().user;
    if (_deliveryType == 'delivery' && _hasAddress && user != null) {
      final houseChanged = _houseCtrl.text.trim() != (user.addressHouse ?? '');
      final townChanged = _townCtrl.text.trim() != (user.addressTown ?? '');
      if (houseChanged || townChanged) {
        // Fire-and-forget — don't block order placement
        context.read<AuthProvider>().updateProfile({
          if (_houseCtrl.text.trim().isNotEmpty)
            'address_house': _houseCtrl.text.trim(),
          if (_townCtrl.text.trim().isNotEmpty)
            'address_town': _townCtrl.text.trim(),
          if (_stateCtrl.text.trim().isNotEmpty)
            'address_state': _stateCtrl.text.trim(),
          if (_pincodeCtrl.text.trim().isNotEmpty)
            'address_pincode': _pincodeCtrl.text.trim(),
        });
      }
    }

    final orderProvider = context.read<OrderProvider>();
    final coinsToSend =
        (_useCoins && cart.coinsToRedeem > 0) ? cart.coinsToRedeem : 0;

    final deliveryAddr = _deliveryType == 'delivery'
        ? [
            _houseCtrl.text.trim(),
            _townCtrl.text.trim(),
            _stateCtrl.text.trim(),
            _pincodeCtrl.text.trim()
          ].where((s) => s.isNotEmpty).join(', ')
        : null;

    final orderData = <String, dynamic>{
      'items': cart.toOrderItems(),
      'location_id': cart.selectedLocationId,
      'delivery_type': _deliveryType,
      if (deliveryAddr != null) 'delivery_address': deliveryAddr,
      if (cart.couponCode != null) 'coupon_code': cart.couponCode,
      if (_instructionsCtrl.text.trim().isNotEmpty)
        'special_instructions': _instructionsCtrl.text.trim(),
      'payment_method': _paymentMethod,
      if (coinsToSend > 0) 'coins_to_redeem': coinsToSend,
    };

    final result = await orderProvider.placeOrder(orderData);

    if (result == null) {
      AppLoader.hide();
      setState(() => _placingOrder = false);
      if (!mounted) return;
      AppToast.error(context, orderProvider.error ?? 'Failed to place order');
      return;
    }

    if (_paymentMethod == 'online') {
      try {
        final dynamic payResult =
            await ApiService.createPaymentOrder(result['order_id'], 'payu');
        debugPrint('[PAYMENT_DEBUG]: PayResult type: ${payResult.runtimeType}');
        debugPrint('[PAYMENT_DEBUG]: result: $payResult');

        String? payUrl;
        if (payResult is String) {
          payUrl = payResult;
        } else if (payResult is Map) {
          payUrl = payResult['payment_url'] ??
              payResult['url'] ??
              payResult['redirect_url'] ??
              payResult['payment_link'] ??
              payResult['paymentLink'] ??
              payResult['checkout_url'] ??
              payResult['checkoutUrl'] ??
              payResult['pay_url'] ??
              payResult['link'] ??
              payResult['form_url'];

          // Fallback for PayU raw parameters
          if (payUrl == null && payResult.containsKey('payu_params')) {
            debugPrint(
                '[PAYMENT_DEBUG] payu_params detected. Constructing auto-submit form...');
            final params = Map<String, dynamic>.from(payResult['payu_params']);

            // Determine endpoint (test vs production)
            final isTest = params['key'] == 'your_payu_key' ||
                (params['key'] ?? '').toString().toLowerCase().contains('test');
            final endpoint = isTest
                ? 'https://test.payu.in/_payment'
                : 'https://secure.payu.in/_payment';

            // Build self-submitting HTML form
            String formHtml =
                '<html><body onload="document.f.submit();"><form id="f" name="f" method="post" action="$endpoint">';
            params.forEach((k, v) => formHtml +=
                '<input type="hidden" name="${k.toString()}" value="${v.toString()}">');
            formHtml += '</form></body></html>';

            // Encode as Data URI for url_launcher
            payUrl =
                'data:text/html;base64,${base64Encode(utf8.encode(formHtml))}';
          }
        }

        AppLoader.hide();
        setState(() => _placingOrder = false);
        if (!mounted) return;

        if (payUrl != null && payUrl.isNotEmpty) {
          try {
            debugPrint('[PAYMENT_DEBUG] Launching Payment interface...');
            final Uri uri = Uri.parse(payUrl);
            final launched =
                await launchUrl(uri, mode: LaunchMode.externalApplication);

            if (launched) {
              debugPrint('[PAYMENT_DEBUG] Launcher success!');
            } else {
              debugPrint('[PAYMENT_DEBUG] Launcher report FALSE');
            }
          } catch (e) {
            debugPrint('[PAYMENT_DEBUG] launchUrl error: $e');
            if (mounted) {
              AppToast.error(context, 'Could not open browser for payment: $e');
            }
          }

          if (!mounted) return;
          // Redirect to order details instead of confirm screen, as payment is pending
          AppToast.success(context, 'Order placed! Please complete payment.');
          cart.clear();
          context.read<AuthProvider>().refreshUser();
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/order-detail',
            (r) => false,
            arguments: result['order_id'],
          );
          return;
        } else {
          debugPrint('[PAYMENT_DEBUG] payUrl was null or empty');
        }
        AppToast.error(context,
            'Payment gateway returned no URL. Please check My Orders.');
      } catch (e) {
        AppLoader.hide();
        setState(() => _placingOrder = false);
        if (!mounted) return;
        AppToast.error(context, 'Payment error: $e');
      }
    } else {
      // Cash on Delivery flow
      AppLoader.hide();
      setState(() => _placingOrder = false);
      if (!mounted) return;
      AppToast.success(context, 'Order placed successfully!');
      cart.clear();
      context.read<AuthProvider>().refreshUser();
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/order-confirm',
        (r) => r.settings.name == '/home',
        arguments: {
          'order_id': result['order_id'],
          'order_number': result['order_number'],
          'total': result['total_amount'],
          'coins_redeemed': result['coins_redeemed'] ?? 0,
        },
      );
    }
  }

  void _toggleCoins(bool val, CartProvider cart, int coinBalance) {
    setState(() => _useCoins = val);
    if (val) {
      final maxRedeem = coinBalance.clamp(
        0,
        (cart.subtotal - cart.discount + cart.deliveryFee).floor(),
      );
      cart.setCoinsToRedeem(maxRedeem);
    } else {
      cart.setCoinsToRedeem(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.watch<AuthProvider>();
    final coinBalance = auth.user?.coinBalance ?? 0;

    // Sync available coins when user state updates
    if (auth.user != null && cart.availableCoins != auth.user!.coinBalance) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) cart.setAvailableCoins(auth.user!.coinBalance);
      });
    }

    final coinsOff = _useCoins ? cart.coinsToRedeem.toDouble() : 0.0;
    final finalTotal =
        (cart.subtotal - cart.discount - coinsOff + cart.deliveryFee)
            .clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: const Color(AppColors.background),
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          // ── Branch ──────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.store_rounded,
            title: 'Branch',
            child: Row(children: [
              Expanded(
                  child: Text(
                cart.selectedLocationName ?? 'No branch selected',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              )),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/branch-selection'),
                style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero),
                child: const Text('Change', style: TextStyle(fontSize: 12)),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Delivery Type ────────────────────────────────────────────
          _SectionCard(
            icon: Icons.delivery_dining_rounded,
            title: 'Delivery Type',
            child: Row(children: [
              Expanded(
                  child: _TypeButton(
                label: 'Delivery',
                icon: Icons.delivery_dining_rounded,
                selected: _deliveryType == 'delivery',
                onTap: () => setState(() => _deliveryType = 'delivery'),
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: _TypeButton(
                label: 'Pickup',
                icon: Icons.storefront_rounded,
                selected: _deliveryType == 'pickup',
                onTap: () => setState(() => _deliveryType = 'pickup'),
              )),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Delivery Address ─────────────────────────────────────────
          if (_deliveryType == 'delivery') ...[
            _SectionCard(
              icon: Icons.location_on_rounded,
              title: 'Delivery Address',
              subtitle: 'Saved to your profile',
              child: Column(children: [
                TextFormField(
                  controller: _houseCtrl,
                  decoration: const InputDecoration(
                    labelText: 'House / Flat No. & Building *',
                    hintText: 'Flat 4B, Sunrise Apartments',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _townCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Town / Area *',
                    hintText: 'Indiranagar',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: TextFormField(
                    controller: _stateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'State',
                      hintText: 'Karnataka',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextFormField(
                    controller: _pincodeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Pincode *',
                      hintText: '560038',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  )),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          // ── Special Instructions ─────────────────────────────────────
          _SectionCard(
            icon: Icons.notes_rounded,
            title: 'Special Instructions',
            subtitle: 'Optional',
            child: TextFormField(
              controller: _instructionsCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Extra spicy, no onions...',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Loyalty Coins ────────────────────────────────────────────
          _CoinRedemptionCard(
            coinBalance: coinBalance,
            useCoins: _useCoins,
            coinsToRedeem: cart.coinsToRedeem,
            finalTotal: finalTotal,
            onToggle: (val) => _toggleCoins(val, cart, coinBalance),
          ),
          const SizedBox(height: 12),

          // ── Payment Method ───────────────────────────────────────────
          _SectionCard(
            icon: Icons.payment_rounded,
            title: 'Payment Method',
            child: Column(children: [
              _PaymentOption(
                value: 'cash_on_delivery',
                selected: _paymentMethod,
                title: 'Cash on Delivery',
                subtitle: 'Pay when your order arrives',
                icon: Icons.money_rounded,
                onTap: () =>
                    setState(() => _paymentMethod = 'cash_on_delivery'),
              ),
              const SizedBox(height: 8),
              _PaymentOption(
                value: 'online',
                selected: _paymentMethod,
                title: 'Online Payment',
                subtitle: 'UPI, Card, Net Banking',
                icon: Icons.account_balance_wallet_rounded,
                onTap: () => setState(() => _paymentMethod = 'online'),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Bill Summary ─────────────────────────────────────────────
          _BillSummaryCard(
            cart: cart,
            useCoins: _useCoins,
            coinsOff: coinsOff,
            finalTotal: finalTotal,
          ),
          const SizedBox(height: 24),
        ],
      ),

      // ── Sticky Place Order Button ────────────────────────────────────
      bottomNavigationBar: _PlaceOrderBar(
        finalTotal: finalTotal,
        paymentMethod: _paymentMethod,
        placing: _placingOrder,
        onTap: _placeOrder,
      ),
    );
  }
}

// ─── COIN REDEMPTION CARD ─────────────────────────────────────────────────────
class _CoinRedemptionCard extends StatelessWidget {
  final int coinBalance, coinsToRedeem;
  final bool useCoins;
  final double finalTotal;
  final ValueChanged<bool> onToggle;

  const _CoinRedemptionCard({
    required this.coinBalance,
    required this.useCoins,
    required this.coinsToRedeem,
    required this.finalTotal,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final canRedeem = coinBalance > 0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: useCoins
              ? const Color(AppColors.coins).withValues(alpha: 0.6)
              : Colors.grey.shade100,
          width: useCoins ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(AppColors.coins).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.stars_rounded,
                    color: Color(AppColors.coins), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Loyalty Coins',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    Text(
                      canRedeem
                          ? 'You have $coinBalance coins = ₹$coinBalance'
                          : 'No coins yet — earn 1 coin per ₹10 spent',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            canRedeem ? FontWeight.w600 : FontWeight.w400,
                        color: canRedeem
                            ? const Color(AppColors.coins)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ])),
              Switch(
                value: useCoins && canRedeem,
                activeThumbColor: const Color(AppColors.coins),
                onChanged: canRedeem ? onToggle : null,
              ),
            ]),
          ),

          // Expanded detail
          if (useCoins && coinsToRedeem > 0) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(AppColors.coins).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Color(AppColors.coins), size: 16),
                        const SizedBox(width: 8),
                        Text('Redeeming $coinsToRedeem coins',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(AppColors.coins),
                                fontSize: 13)),
                      ]),
                      Text('- ₹$coinsToRedeem',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(AppColors.coins),
                              fontSize: 14)),
                    ]),
                const SizedBox(height: 10),
                Divider(
                    color: const Color(AppColors.coins).withValues(alpha: 0.2),
                    height: 1),
                const SizedBox(height: 10),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('You pay',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      Text('₹${finalTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: Color(AppColors.primary))),
                    ]),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── BILL SUMMARY ─────────────────────────────────────────────────────────────
class _BillSummaryCard extends StatelessWidget {
  final CartProvider cart;
  final bool useCoins;
  final double coinsOff, finalTotal;
  const _BillSummaryCard(
      {required this.cart,
      required this.useCoins,
      required this.coinsOff,
      required this.finalTotal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.receipt_long_rounded,
              size: 18, color: Color(AppColors.primary)),
          SizedBox(width: 8),
          Text('Order Summary',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
        const SizedBox(height: 14),
        _SummaryRow(
            label:
                'Subtotal (${cart.itemCount} item${cart.itemCount > 1 ? 's' : ''})',
            amount: cart.subtotal),
        if (cart.discount > 0) ...[
          const SizedBox(height: 8),
          _SummaryRow(
              label: 'Coupon (${cart.couponCode ?? ''})',
              amount: -cart.discount,
              color: const Color(AppColors.success)),
        ],
        const SizedBox(height: 8),
        _SummaryRow(
          label: cart.deliveryType == 'pickup'
              ? 'Pickup (Free)'
              : cart.deliveryFee == 0
                  ? 'Delivery (Free above ₹300)'
                  : 'Delivery Fee',
          amount: cart.deliveryFee,
          color: cart.deliveryFee == 0 ? const Color(AppColors.success) : null,
        ),
        if (useCoins && coinsOff > 0) ...[
          const SizedBox(height: 8),
          _SummaryRow(
              label: 'Coins Redeemed (${cart.coinsToRedeem})',
              amount: -coinsOff,
              color: const Color(AppColors.coins)),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Divider(color: Colors.grey.shade100, thickness: 1.5),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total Payable',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          Text('₹${finalTotal.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: Color(AppColors.primary))),
        ]),
        if (cart.discount > 0 || coinsOff > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(AppColors.success).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.celebration_rounded,
                  color: Color(AppColors.success), size: 15),
              const SizedBox(width: 6),
              Text(
                  "Saving ₹${(cart.discount + coinsOff).toStringAsFixed(0)} on this order!",
                  style: const TextStyle(
                      color: Color(AppColors.success),
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ─── PLACE ORDER BAR ──────────────────────────────────────────────────────────
class _PlaceOrderBar extends StatelessWidget {
  final double finalTotal;
  final String paymentMethod;
  final bool placing;
  final VoidCallback onTap;
  const _PlaceOrderBar(
      {required this.finalTotal,
      required this.paymentMethod,
      required this.placing,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: placing ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(AppColors.primary),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: placing
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: PizzaSpinner(
                      color: Colors.white, size: 24))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(
                      paymentMethod == 'cash_on_delivery'
                          ? Icons.shopping_bag_rounded
                          : Icons.lock_rounded,
                      color: Colors.white,
                      size: 18),
                  const SizedBox(width: 10),
                  Text(
                      paymentMethod == 'cash_on_delivery'
                          ? 'Place Order'
                          : 'Pay Now',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('₹${finalTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15)),
                  ),
                ]),
        ),
      ),
    );
  }
}

// ─── SECTION CARD ─────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  const _SectionCard(
      {required this.icon,
      required this.title,
      this.subtitle,
      required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 17, color: const Color(AppColors.primary)),
            const SizedBox(width: 8),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            if (subtitle != null) ...[
              const SizedBox(width: 6),
              Text(subtitle!,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

// ─── TYPE BUTTON ──────────────────────────────────────────────────────────────
class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TypeButton(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(AppColors.primary)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected
                    ? const Color(AppColors.primary)
                    : Colors.grey.shade200),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 16,
                color: selected
                    ? Colors.white
                    : const Color(AppColors.textSecondary)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: selected
                        ? Colors.white
                        : const Color(AppColors.textPrimary))),
          ]),
        ),
      );
}

// ─── PAYMENT OPTION ───────────────────────────────────────────────────────────
class _PaymentOption extends StatelessWidget {
  final String value, selected, title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _PaymentOption(
      {required this.value,
      required this.selected,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(AppColors.primary).withValues(alpha: 0.06)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected
                  ? const Color(AppColors.primary)
                  : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(AppColors.primary).withValues(alpha: 0.1)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 18,
                color: isSelected
                    ? const Color(AppColors.primary)
                    : Colors.grey.shade500),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isSelected
                            ? const Color(AppColors.primary)
                            : const Color(AppColors.textPrimary))),
                Text(subtitle,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ])),
          if (isSelected)
            const Icon(Icons.check_circle_rounded,
                color: Color(AppColors.primary), size: 20),
        ]),
      ),
    );
  }
}

// ─── SUMMARY ROW ──────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color? color;
  const _SummaryRow({required this.label, required this.amount, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ??
        (amount < 0
            ? const Color(AppColors.success)
            : const Color(AppColors.textPrimary));
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500))),
      Text(
        amount == 0
            ? 'Free'
            : '${amount < 0 ? "-" : ""}₹${amount.abs().toStringAsFixed(0)}',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c),
      ),
    ]);
  }
}
