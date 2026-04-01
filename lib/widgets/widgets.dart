import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import 'app_loader.dart';
export 'app_loader.dart';
export 'cart_fab.dart';

// ─── PIZZA NET IMAGE ──────────────────────────────────────────────

class PizzaNetImage extends StatelessWidget {
  final String? url;
  final double? width, height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const PizzaNetImage({
    super.key,
    this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = url != null && url!.isNotEmpty ? url! : null;
    final child = imageUrl != null
        ? CachedNetworkImage(
            imageUrl: imageUrl,
            width: width,
            height: height,
            fit: fit,
            httpHeaders: const {'Accept': 'image/*'},
            placeholder: (ctx, url) => _shimmer(),
            errorWidget: (ctx, url, err) {
              debugPrint('Image load error: $url => $err');
              return _placeholder();
            },
          )
        : _placeholder();

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _shimmer() => Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade50,
        child: Container(width: width, height: height, color: Colors.white),
      );

  Widget _placeholder() => Container(
        width: width,
        height: height,
        color: const Color(0xFFF5F5F5),
        child: Center(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_pizza_rounded,
                size: (width ?? 60) * 0.4,
                color: const Color(AppColors.primary).withValues(alpha: 0.25)),
          ],
        )),
      );
}

// ─── VEG BADGE ────────────────────────────────────────────────────

class VegBadge extends StatelessWidget {
  final bool isVeg;
  const VegBadge({super.key, required this.isVeg});

  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          border: Border.all(
            color: isVeg
                ? const Color(AppColors.vegGreen)
                : const Color(AppColors.nonVegRed),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isVeg
                  ? const Color(AppColors.vegGreen)
                  : const Color(AppColors.nonVegRed),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
}

// ─── PRODUCT CARD ─────────────────────────────────────────────────

class ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onAddToCart;

  const ProductCard(
      {super.key,
      required this.product,
      required this.onTap,
      this.onAddToCart});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _pressAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) {
          _pressCtrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _pressCtrl.reverse(),
        child: ScaleTransition(
          scale: _pressAnim,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18)),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: PizzaNetImage(
                            url: widget.product.imageUrl,
                            width: double.infinity),
                      ),
                    ),
                    Positioned(
                        top: 10,
                        left: 10,
                        child: VegBadge(isVeg: widget.product.isVeg)),
                    if (widget.product.isFeatured)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(AppColors.accent),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded,
                                    color: Colors.white, size: 11),
                                SizedBox(width: 3),
                                Text('Featured',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700)),
                              ]),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.product.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (widget.product.description != null) ...[
                        const SizedBox(height: 2),
                        Text(widget.product.description!,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              '₹${widget.product.basePrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Color(AppColors.primary))),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              (widget.onAddToCart ?? widget.onTap)();
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                  color: Color(AppColors.primary),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.add_rounded,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// ─── ORDER STATUS CHIP ────────────────────────────────────────────

class OrderStatusChip extends StatelessWidget {
  final String status;
  const OrderStatusChip({super.key, required this.status});

  Color get _color {
    switch (status) {
      case 'pending':
        return const Color(AppColors.warning);
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.orange;
      case 'out_for_delivery':
        return Colors.indigo;
      case 'delivered':
        return const Color(AppColors.success);
      case 'cancelled':
        return const Color(AppColors.error);
      default:
        return Colors.grey;
    }
  }

  IconData get _icon {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty_rounded;
      case 'confirmed':
        return Icons.check_circle_outline_rounded;
      case 'preparing':
        return Icons.restaurant_rounded;
      case 'out_for_delivery':
        return Icons.delivery_dining_rounded;
      case 'delivered':
        return Icons.celebration_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String get _label {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'preparing':
        return 'Preparing';
      case 'out_for_delivery':
        return 'On the way';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_icon, size: 14, color: _color),
          const SizedBox(width: 5),
          Text(_label,
              style: TextStyle(
                  color: _color, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}

// ─── EMPTY STATE ─────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData? icon;
  final String? emoji;
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onButton;

  const EmptyState({
    super.key,
    this.icon,
    this.emoji,
    required this.title,
    this.subtitle = '',
    this.buttonText,
    this.onButton,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(AppColors.primary).withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: icon != null
                  ? Icon(icon,
                      size: 38,
                      color: const Color(AppColors.primary).withValues(alpha: 0.5))
                  : Center(
                      child: Text(emoji ?? '',
                          style: const TextStyle(fontSize: 38))),
            ),
            const SizedBox(height: 18),
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                textAlign: TextAlign.center),
            if (buttonText != null && onButton != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onButton,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(buttonText!),
                style:
                    ElevatedButton.styleFrom(minimumSize: const Size(160, 46)),
              ),
            ],
          ]),
        ),
      );
}

// ─── SECTION HEADER ──────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? titleIcon;
  final Color? titleIconColor;
  final VoidCallback? onSeeAll;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.titleIcon,
    this.titleIconColor,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          if (titleIcon != null) ...[
            Icon(titleIcon,
                size: 18,
                color: titleIconColor ?? const Color(AppColors.primary)),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                if (subtitle != null)
                  Text(subtitle!,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('See all',
                    style: TextStyle(
                        color: Color(AppColors.primary),
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                Icon(Icons.chevron_right_rounded,
                    color: Color(AppColors.primary), size: 18),
              ]),
            ),
        ],
      );
}

// ─── PRICE ROW ───────────────────────────────────────────────────

class PriceRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;
  final Color? color;

  const PriceRow({
    super.key,
    required this.label,
    required this.amount,
    this.isBold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: isBold ? 16 : 14,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
                color: color ??
                    (isBold
                        ? const Color(AppColors.textPrimary)
                        : const Color(AppColors.textSecondary)),
              )),
          Text(
            amount < 0
                ? '- ₹${(-amount).toStringAsFixed(0)}'
                : '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: isBold ? 18 : 14,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color ??
                  (isBold
                      ? const Color(AppColors.primary)
                      : const Color(AppColors.textPrimary)),
            ),
          ),
        ],
      );
}

// ─── LOADING OVERLAY ─────────────────────────────────────────────

class LoadingOverlay extends StatelessWidget {
  final bool loading;
  final Widget child;
  const LoadingOverlay({super.key, required this.loading, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          child,
          if (loading)
            Container(
              color: Colors.black26,
              child: const Center(
                  child: PizzaSpinner(size: 40)),
            ),
        ],
      );
}

// ─── QUANTITY STEPPER ─────────────────────────────────────────────

class QuantityStepper extends StatelessWidget {
  final int value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const QuantityStepper({
    super.key,
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(AppColors.background),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _btn(Icons.remove_rounded, onDecrement),
            SizedBox(
              width: 34,
              child: Text('$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            _btn(Icons.add_rounded, onIncrement),
          ],
        ),
      );

  Widget _btn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(AppColors.primary).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(AppColors.primary), size: 17),
        ),
      );
}

// ─── TOP SNACK BANNER ─────────────────────────────────────────────

// ─── showSnack delegates to AppToast ─────────────────────────────
// Keep showSnack for compatibility with existing screens
void showSnack(BuildContext context, String message, {bool isError = false}) {
  if (isError) {
    AppToast.error(context, message);
  } else {
    AppToast.success(context, message);
  }
}


