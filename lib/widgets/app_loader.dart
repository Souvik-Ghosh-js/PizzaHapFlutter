import 'package:flutter/material.dart';
import '../config/app_config.dart';

// ─────────────────────────────────────────────────────────────────
// GLOBAL BEAUTIFUL LOADER OVERLAY
// Usage:
//   AppLoader.show(context);          // show
//   AppLoader.hide();                 // hide
//   AppLoader.show(context, message: 'Placing order...');
// ─────────────────────────────────────────────────────────────────

class AppLoader {
  static OverlayEntry? _overlay;

  static void show(BuildContext context, {String? message}) {
    hide(); // Always clear previous
    final entry = OverlayEntry(
      builder: (_) => _LoaderOverlay(message: message),
    );
    _overlay = entry;
    Overlay.of(context).insert(entry);
  }

  static void hide() {
    try {
      _overlay?.remove();
    } catch (_) {}
    _overlay = null;
  }
}

class _LoaderOverlay extends StatefulWidget {
  final String? message;
  const _LoaderOverlay({this.message});
  @override
  State<_LoaderOverlay> createState() => _LoaderOverlayState();
}

class _LoaderOverlayState extends State<_LoaderOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated pizza spinner
                  const PizzaSpinner(),
                  if (widget.message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      widget.message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(AppColors.textPrimary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PizzaSpinner extends StatefulWidget {
  final double size;
  final Color? color;
  const PizzaSpinner({super.key, this.size = 56, this.color});

  @override
  State<PizzaSpinner> createState() => _PizzaSpinnerState();
}

class _PizzaSpinnerState extends State<PizzaSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Transform.scale(
        scale: widget.size / 56.0,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring
            RotationTransition(
              turns: _spin,
              child: CustomPaint(
                size: const Size(56, 56),
                painter: _ArcPainter(color: widget.color ?? const Color(AppColors.primary)),
              ),
            ),
            // Logo center
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: (widget.color ?? const Color(AppColors.primary)).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.local_pizza_rounded,
                    color: widget.color ?? const Color(AppColors.primary),
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color;
  _ArcPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final paintFaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width / 2 - 2);

    // Full faint circle
    canvas.drawCircle(Offset(size.width / 2, size.height / 2),
        size.width / 2 - 2, paintFaint);

    // Arc
    canvas.drawArc(rect, -1.57, 4.5, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────
// BEAUTIFUL TOAST SYSTEM
// Usage:
//   AppToast.success(context, 'Order placed!');
//   AppToast.error(context, 'Something went wrong');
//   AppToast.info(context, 'Processing...');
// ─────────────────────────────────────────────────────────────────

class AppToast {
  static OverlayEntry? _active;

  static void success(BuildContext context, String message) =>
      _show(context, message, _ToastType.success);

  static void error(BuildContext context, String message) =>
      _show(context, message, _ToastType.error);

  static void info(BuildContext context, String message) =>
      _show(context, message, _ToastType.info);

  static void warning(BuildContext context, String message) =>
      _show(context, message, _ToastType.warning);

  static void _show(BuildContext context, String message, _ToastType type) {
    _dismiss();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        type: type,
        onDismiss: () {
          try {
            entry.remove();
          } catch (_) {}
          if (_active == entry) _active = null;
        },
      ),
    );
    _active = entry;
    Overlay.of(context).insert(entry);
  }

  static void _dismiss() {
    try {
      _active?.remove();
    } catch (_) {}
    _active = null;
  }
}

enum _ToastType { success, error, info, warning }

class _ToastWidget extends StatefulWidget {
  final String message;
  final _ToastType type;
  final VoidCallback onDismiss;
  const _ToastWidget(
      {required this.message, required this.type, required this.onDismiss});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 360));
    _slide = Tween<Offset>(begin: const Offset(0, -1.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(_duration, _dismiss);
  }

  Duration get _duration {
    if (widget.type == _ToastType.error) return const Duration(seconds: 4);
    return const Duration(seconds: 3);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    if (mounted) widget.onDismiss();
  }

  Color get _bgColor {
    switch (widget.type) {
      case _ToastType.success:
        return const Color(0xFF18A558);
      case _ToastType.error:
        return const Color(0xFFDC2626);
      case _ToastType.warning:
        return const Color(0xFFF59E0B);
      case _ToastType.info:
        return const Color(0xFF1A1A1A);
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case _ToastType.success:
        return Icons.check_circle_rounded;
      case _ToastType.error:
        return Icons.error_rounded;
      case _ToastType.warning:
        return Icons.warning_rounded;
      case _ToastType.info:
        return Icons.info_rounded;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: top + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onTap: _dismiss,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _bgColor.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_icon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.7), size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
