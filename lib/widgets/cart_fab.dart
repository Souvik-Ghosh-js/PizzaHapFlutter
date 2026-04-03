import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../config/app_config.dart';

/// A floating cart button that appears on any screen when the cart has items.
/// Use as Scaffold.floatingActionButton on pushed routes (menu, product detail, etc.)
/// The MainShell handles this automatically for its own tabs.
class CartFAB extends StatefulWidget {
  const CartFAB({super.key});
  @override
  State<CartFAB> createState() => _CartFABState();
}

class _CartFABState extends State<CartFAB> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scale = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    if (cart.itemCount == 0) return const SizedBox.shrink();

    // Animate in when cart gets items
    _ctrl.forward();

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.pushNamed(context, '/cart');
        },
        child: Container(
          height: 54,
          constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(AppColors.primary), Color(AppColors.primaryLight)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(27),
            boxShadow: [
              BoxShadow(
                color: const Color(AppColors.primary).withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${cart.itemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    cart.itemCount == 1 ? '1 item in cart' : '${cart.itemCount} items in cart',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700,
                    ),
                  ),
                ]),
                Row(children: [
                  Text(
                    '₹${cart.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 13),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
