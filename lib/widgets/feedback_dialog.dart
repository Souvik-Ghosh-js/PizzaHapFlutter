import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';
import 'widgets.dart';

class FeedbackDialog extends StatefulWidget {
  final Order order;
  final VoidCallback? onSuccess;

  const FeedbackDialog({super.key, required this.order, this.onSuccess});

  static void show(BuildContext context, Order order, {VoidCallback? onSuccess}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => FeedbackDialog(order: order, onSuccess: onSuccess),
    );
  }

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  int _foodRating = 0;
  int _deliveryRating = 0;
  int _overallRating = 0;
  final _commentCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _showThankYouAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 2), () {
          if (ctx.mounted) Navigator.pop(ctx);
        });
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(AppColors.success).withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(AppColors.success),
                        size: 80,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Thank You!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Your feedback helps us improve.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate Your Order'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Food Quality',
            style: TextStyle(fontWeight: FontWeight.w700)),
        _starRow(
            rating: _foodRating,
            onChanged: (r) => setState(() => _foodRating = r)),
        const SizedBox(height: 12),
        if (widget.order.deliveryType == 'delivery') ...[
          const Text('Delivery',
              style: TextStyle(fontWeight: FontWeight.w700)),
          _starRow(
              rating: _deliveryRating,
              onChanged: (r) => setState(() => _deliveryRating = r)),
          const SizedBox(height: 12),
        ],
        const Text('Overall Experience',
            style: TextStyle(fontWeight: FontWeight.w700)),
        _starRow(
            rating: _overallRating,
            onChanged: (r) => setState(() => _overallRating = r)),
        const SizedBox(height: 12),
        TextField(
          controller: _commentCtrl,
          maxLines: 3,
          decoration: InputDecoration(
              hintText: 'Leave a comment... (optional)',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              )),
        ),
      ])),
      actions: [
        TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final shown = prefs.getStringList('dismissed_review_ids') ?? [];
              if (!shown.contains(widget.order.id.toString())) {
                shown.add(widget.order.id.toString());
                await prefs.setStringList('dismissed_review_ids', shown);
              }
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Maybe Later')),
        ElevatedButton(
          onPressed: _loading ? null : () async {
            if (_foodRating == 0 || _overallRating == 0) {
              AppToast.error(context, 'Please rate both food and experience');
              return;
            }
            setState(() => _loading = true);
            try {
              await ApiService.submitOrderFeedback(
                widget.order.id,
                foodRating: _foodRating,
                deliveryRating: widget.order.deliveryType == 'delivery' &&
                        _deliveryRating > 0
                    ? _deliveryRating
                    : null,
                overallRating: _overallRating,
                comment: _commentCtrl.text.trim().isEmpty
                    ? null
                    : _commentCtrl.text.trim(),
              );
              if (!mounted) return;
              final prefs = await SharedPreferences.getInstance();
              final shown = prefs.getStringList('dismissed_review_ids') ?? [];
              if (!shown.contains(widget.order.id.toString())) {
                shown.add(widget.order.id.toString());
                await prefs.setStringList('dismissed_review_ids', shown);
              }
              if (!mounted) return;
              Navigator.pop(context);
              _showThankYouAnimation();
              if (widget.onSuccess != null) widget.onSuccess!();
            } on ApiException catch (e) {
              if (mounted) {
                setState(() => _loading = false);
                AppToast.error(context, e.message);
              }
            } catch (e) {
              if (mounted) {
                setState(() => _loading = false);
                AppToast.error(context, e.toString());
              }
            }
          },
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _loading 
            ? const SizedBox(width: 20, height: 20, child: PizzaSpinner(size: 20, color: Colors.white))
            : const Text('Submit'),
        ),
      ],
    );
  }

  Widget _starRow({required int rating, required ValueChanged<int> onChanged}) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (i) {
          final star = i + 1;
          return IconButton(
            onPressed: () => onChanged(star),
            icon: Icon(
              star <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
              color: const Color(AppColors.warning),
              size: 32,
            ),
          );
        }),
      ),
    );
  }
}
