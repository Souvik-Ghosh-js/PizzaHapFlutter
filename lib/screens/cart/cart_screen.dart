
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../config/app_config.dart';
import '../../widgets/widgets.dart';
import '../../services/api_service.dart';

class CartScreen extends StatefulWidget {
  final String? autoCoupon;
  const CartScreen({super.key, this.autoCoupon});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen>
    with SingleTickerProviderStateMixin {
  final _couponCtrl = TextEditingController();
  bool _validatingCoupon = false;
  late AnimationController _checkoutController;

  @override
  void initState() {
    super.initState();
    _checkoutController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    if (widget.autoCoupon != null && widget.autoCoupon!.isNotEmpty) {
      _couponCtrl.text = widget.autoCoupon!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _validateCoupon());
    }
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    _checkoutController.dispose();
    super.dispose();
  }

  Future<void> _validateCoupon() async {
    final cart = context.read<CartProvider>();
    if (_couponCtrl.text.trim().isEmpty) return;
    setState(() => _validatingCoupon = true);
    try {
      final coupon = await ApiService.validateCoupon(
          _couponCtrl.text.trim(), cart.subtotal,
          items: cart.items
              .map((i) => {
                    'product_id': i.product.id,
                    'size_code': i.size.sizeCode,
                  })
              .toList());
      if (!mounted) return;
      cart.applyCoupon(coupon);
      if (coupon.isBogo) {
        final free = cart.bogoFreeItem;
        if (free != null) {
          AppToast.success(context,
              'BOGO applied! FREE ${free.size.sizeName} ${free.product.name} with your order!');
        } else {
          AppToast.success(context,
              'BOGO applied! Add a Medium or Large pizza to get a smaller one free!');
        }
      } else {
        AppToast.success(context, 'Coupon applied! You\'re saving!');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _validatingCoupon = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    if (cart.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(AppColors.background),
        appBar: AppBar(
          automaticallyImplyLeading: ModalRoute.of(context)?.canPop ?? false,
          title: const Text('My Cart'),
        ),
        body: EmptyState(
          icon: Icons.shopping_cart_outlined,
          title: 'Your cart is empty',
          subtitle: 'Add some delicious pizzas to get started!',
          buttonText: 'Browse Menu',
          onButton: () => Navigator.pushNamed(context, '/menu'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(AppColors.background),
      appBar: AppBar(
        automaticallyImplyLeading: ModalRoute.of(context)?.canPop ?? false,
        title: Text(
            'Cart    ${cart.itemCount} item${cart.itemCount > 1 ? 's' : ''}'),
        actions: [
          TextButton.icon(
            onPressed: () => _showClearDialog(cart),
            icon: const Icon(Icons.delete_outline_rounded, size: 17),
            label: const Text('Clear'),
            style: TextButton.styleFrom(
                foregroundColor: const Color(AppColors.error)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              children: [
                // Cart items
                ...cart.items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return _CartItemCard(
                    item: item,
                    onRemove: () {
                      HapticFeedback.mediumImpact();
                      cart.removeItem(idx);
                    },
                    onDecrement: () =>
                        cart.updateQuantity(idx, item.quantity - 1),
                    onIncrement: () =>
                        cart.updateQuantity(idx, item.quantity + 1),
                  );
                }),
                const SizedBox(height: 10),

                // Coupon section
                _CouponSection(
                  couponCtrl: _couponCtrl,
                  validating: _validatingCoupon,
                  appliedCoupon: cart.appliedCoupon,
                  onValidate: _validateCoupon,
                  onRemove: () {
                    cart.removeCoupon();
                    _couponCtrl.clear();
                  },
                  onBrowse: () => Navigator.pushNamed(context, '/coupons'),
                ),
                const SizedBox(height: 10),

                // Bill summary
                _BillCard(cart: cart),
              ],
            ),
          ),
          // Checkout button
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 14, 16, MediaQuery.of(context).padding.bottom + 14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4))
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pushNamed(context, '/checkout');
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 18),
                  const SizedBox(width: 8),
                  const Text('Proceed to Checkout',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('₹${cart.total.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(CartProvider cart) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                  color: const Color(AppColors.error).withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Color(AppColors.error), size: 28),
            ),
            const SizedBox(height: 16),
            const Text('Clear Cart?',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 8),
            Text('Remove all ${cart.itemCount} items from cart?',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(
                  child: ElevatedButton(
                onPressed: () {
                  cart.clear();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppColors.error)),
                child: const Text('Clear'),
              )),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onRemove, onDecrement, onIncrement;
  const _CartItemCard(
      {required this.item,
      required this.onRemove,
      required this.onDecrement,
      required this.onIncrement});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child:
              PizzaNetImage(url: item.product.imageUrl, width: 76, height: 76),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              VegBadge(isVeg: item.product.isVeg),
              const SizedBox(width: 7),
              Expanded(
                child: Text(item.product.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(AppColors.error).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Color(AppColors.error), size: 15),
                ),
              ),
            ]),
            const SizedBox(height: 3),
            Text(item.size.sizeName,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            if (item.crust != null)
              Text('${item.crust!.name} crust',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            if (item.selectedToppings.isNotEmpty)
              Text('+${item.selectedToppings.map((t) => t.name).join(', ')}',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('₹${item.totalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(AppColors.primary))),
              _QuantityRow(
                  value: item.quantity,
                  onDecrement: onDecrement,
                  onIncrement: onIncrement),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _QuantityRow extends StatelessWidget {
  final int value;
  final VoidCallback onDecrement, onIncrement;
  const _QuantityRow(
      {required this.value,
      required this.onDecrement,
      required this.onIncrement});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(AppColors.background),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _btn(Icons.remove_rounded, onDecrement),
        SizedBox(
          width: 30,
          child: Text('$value',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ),
        _btn(Icons.add_rounded, onIncrement),
      ]),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(AppColors.primary).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(AppColors.primary), size: 16),
        ),
      );
}

class _CouponSection extends StatelessWidget {
  final TextEditingController couponCtrl;
  final bool validating;
  final dynamic appliedCoupon;
  final VoidCallback onValidate, onRemove, onBrowse;
  const _CouponSection(
      {required this.couponCtrl,
      required this.validating,
      required this.appliedCoupon,
      required this.onValidate,
      required this.onRemove,
      required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
        ],
      ),
      child: appliedCoupon != null
          ? Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: const Color(AppColors.success).withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.local_offer_rounded,
                    color: Color(AppColors.success), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(appliedCoupon!.code,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(AppColors.success),
                            fontSize: 14)),
                    Text(
                        appliedCoupon!.isBogo
                            ? 'Buy 1 Get 1 — smaller size FREE!'
                            : 'Saving ₹${appliedCoupon!.calculatedDiscount?.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ])),
              TextButton(
                onPressed: onRemove,
                style: TextButton.styleFrom(
                    foregroundColor: const Color(AppColors.error)),
                child: const Text('Remove'),
              ),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.local_offer_outlined,
                    size: 17, color: Color(AppColors.primary)),
                SizedBox(width: 8),
                Text('Have a coupon?',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: couponCtrl,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, letterSpacing: 1.2),
                    decoration: const InputDecoration(
                      hintText: 'ENTER CODE',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: validating ? null : onValidate,
                    style: ElevatedButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 20)),
                    child: validating
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: PizzaSpinner(size: 20, color: Colors.white))
                        : const Text('Apply',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onBrowse,
                child: const Row(children: [
                  Icon(Icons.discount_outlined,
                      size: 13, color: Color(AppColors.primary)),
                  SizedBox(width: 4),
                  Text('Browse available coupons',
                      style: TextStyle(
                          color: Color(AppColors.primary),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: Color(AppColors.primary))),
                ]),
              ),
            ]),
    );
  }
}

class _BillCard extends StatelessWidget {
  final CartProvider cart;
  const _BillCard({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.receipt_long_outlined,
              size: 18, color: Color(AppColors.textPrimary)),
          SizedBox(width: 8),
          Text('Bill Summary',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        const SizedBox(height: 14),
        PriceRow(label: 'Subtotal', amount: cart.subtotal),
        if (cart.discount > 0) ...[
          const SizedBox(height: 6),
          PriceRow(
              label: 'Discount (${cart.appliedCoupon?.code ?? ''})',
              amount: -cart.discount,
              color: const Color(AppColors.success)),
        ],
        if (cart.bogoFreeItem != null) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '🎁 ${cart.bogoFreeItem!.product.name} (${cart.bogoFreeItem!.size.sizeName})',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(AppColors.success)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Text('FREE',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(AppColors.success))),
            ],
          ),
          if (cart.freeItemExtrasTotal > 0) ...[
            const SizedBox(height: 6),
            PriceRow(
                label: 'Extras on free pizza', amount: cart.freeItemExtrasTotal),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => showFreeItemExtrasSheet(context, cart),
              child: Text(
                cart.freeItemCrust == null && cart.freeItemToppings.isEmpty
                    ? '+ Add crust/toppings to free pizza (payable)'
                    : 'Edit free pizza extras',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(AppColors.primary),
                    decoration: TextDecoration.underline,
                    decorationColor: Color(AppColors.primary)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 6),
        PriceRow(
          label: cart.deliveryType == 'pickup'
              ? 'Delivery (Pickup)'
              : cart.deliveryFee == 0
                  ? 'Delivery (Free!)'
                  : 'Delivery Fee',
          amount: cart.deliveryFee,
          color: cart.deliveryFee == 0 ? const Color(AppColors.success) : null,
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Divider(color: Colors.grey.shade100, thickness: 1.5),
        ),
        PriceRow(label: 'Total', amount: cart.total, isBold: true),
      ]),
    );
  }
}

/// Bottom sheet to pick payable extras (crust addon / toppings) for the
/// BOGO free pizza. The base pizza stays free; only extras are charged.
void showFreeItemExtrasSheet(BuildContext context, CartProvider cart) {
  final free = cart.bogoFreeItem;
  if (free == null) return;
  final product = free.product;
  final sizeCode = free.size.sizeCode;
  CrustType? crust = cart.freeItemCrust;
  final selected = List<Topping>.from(cart.freeItemToppings);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      double extrasTotal() {
        double t = 0;
        if (crust != null) t += product.getCrustPrice(crust!, sizeCode);
        for (final tp in selected) {
          t += product.getToppingPrice(tp, sizeCode);
        }
        return t;
      }

      final crusts =
          product.crusts.where((c) => c.isAvailable).toList();
      final toppings =
          product.toppings.where((t) => t.isAvailable).toList();

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Extras for your FREE ${free.size.sizeName} ${product.name}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                        'The pizza itself is free — extras below are charged.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ]),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  if (crusts.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: Text('Crust',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    RadioListTile<int?>(
                      dense: true,
                      value: null,
                      groupValue: crust?.id,
                      onChanged: (_) => setSheet(() => crust = null),
                      title: const Text('Regular crust (Free)',
                          style: TextStyle(fontSize: 13)),
                    ),
                    ...crusts.map((c) => RadioListTile<int?>(
                          dense: true,
                          value: c.id,
                          groupValue: crust?.id,
                          onChanged: (_) => setSheet(() => crust = c),
                          title: Text(
                              '${c.name}  +₹${product.getCrustPrice(c, sizeCode).toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 13)),
                        )),
                  ],
                  if (toppings.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: Text('Toppings',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    ...toppings.map((t) => CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: selected.any((s) => s.id == t.id),
                          onChanged: (v) => setSheet(() {
                            selected.removeWhere((s) => s.id == t.id);
                            if (v == true) selected.add(t);
                          }),
                          title: Text(
                              '${t.name}  +₹${product.getToppingPrice(t, sizeCode).toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 13)),
                        )),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(children: [
                Expanded(
                  child: Text(
                    extrasTotal() > 0
                        ? 'Extras: ₹${extrasTotal().toStringAsFixed(0)}'
                        : 'No extras',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    cart.setFreeItemExtras(crust, selected);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Apply',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ]),
        ),
      );
    }),
  );
}
