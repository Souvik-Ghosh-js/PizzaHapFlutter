import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../config/app_config.dart';
import 'home/home_screen.dart';
import 'menu/menu_screen.dart';
import 'cart/cart_screen.dart';
import 'orders/orders_screen.dart';
import 'profile/profile_screen.dart';
import '../widgets/feedback_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainShell extends StatefulWidget {
  final int initialTab;
  const MainShell({super.key, this.initialTab = 0});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  late int _currentIndex;
  DateTime? _lastBackPressed;
  late List<AnimationController> _tabControllers;
  Timer? _notifTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _tabControllers = List.generate(
        5,
        (i) => AnimationController(
            vsync: this, duration: const Duration(milliseconds: 200)));
    _tabControllers[_currentIndex].forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
      context.read<NotificationProvider>().load();
      context.read<OrderProvider>().loadActiveOrder();
      _checkPendingReviews();
      // Listen for session expiry events
      context.read<AuthProvider>().addListener(_onAuthChanged);
    });
    
    _notifTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted) {
        context.read<NotificationProvider>().load();
        // Periodically refresh active order status
        context.read<OrderProvider>().loadActiveOrder();
      }
    });
  }

  void _checkAuth() {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    }
  }

  void _checkPendingReviews() async {
    // Only show review dialog if user has NOT already reviewed the order
    // getLatestUnreviewedDeliveredOrder already checks feedback == null
    final orderProvider = context.read<OrderProvider>();
    final order = await orderProvider.getLatestUnreviewedDeliveredOrder();
    if (order != null && order.feedback == null && mounted) {
      final prefs = await SharedPreferences.getInstance();
      final shown = prefs.getStringList('dismissed_review_ids') ?? [];
      if (shown.contains(order.id.toString())) return;

      if (!context.mounted) return;
      FeedbackDialog.show(context, order, onSuccess: () {
        if (mounted) context.read<AuthProvider>().refreshUser();
      });
    }
  }


  void _onAuthChanged() {
    final auth = context.read<AuthProvider>();
    if (auth.sessionExpired && mounted) {
      auth.resetSessionExpired();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    }
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    // Remove auth listener safely
    try { context.read<AuthProvider>().removeListener(_onAuthChanged); } catch (_) {}
    for (final c in _tabControllers) {
      c.dispose();
    }
    super.dispose();
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    MenuScreen(),
    CartScreen(),
    OrdersScreen(),
    ProfileScreen(),
  ];

  void _setTab(int i) {
    if (i == _currentIndex) return;
    _tabControllers[_currentIndex].reverse();
    setState(() => _currentIndex = i);
    _tabControllers[i].forward();
    HapticFeedback.selectionClick();
  }

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      _setTab(0);
      return false;
    }
    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      showSnackTop(context, 'Press back again to exit');
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    // Don't show floating cart when on the cart tab (index 2)
    final showFloatingCart = cart.itemCount > 0 && _currentIndex != 2;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        // Floating cart button — shows on all tabs except cart tab when items in cart
        floatingActionButton: showFloatingCart
            ? _FloatingCartButton(
                itemCount: cart.itemCount,
                total: cart.total,
                onTap: () => _setTab(2),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: _PremiumBottomBar(
          currentIndex: _currentIndex,
          cartCount: cart.itemCount,
          onTap: _setTab,
          controllers: _tabControllers,
          hasFloatingCart: showFloatingCart,
        ),
      ),
    );
  }
}

// ─── FLOATING CART BUTTON ─────────────────────────────────────────
class _FloatingCartButton extends StatefulWidget {
  final int itemCount;
  final double total;
  final VoidCallback onTap;
  const _FloatingCartButton({
    required this.itemCount,
    required this.total,
    required this.onTap,
  });
  @override
  State<_FloatingCartButton> createState() => _FloatingCartButtonState();
}

class _FloatingCartButtonState extends State<_FloatingCartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _scale = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return SlideTransition(
      position: _slide,
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          // Sits just above the bottom nav bar
          padding: EdgeInsets.only(bottom: 68 + bottomPad),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onTap();
            },
            child: Container(
              height: 54,
              constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(AppColors.primary),
                    Color(AppColors.primaryLight)
                  ],
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
                    // Cart icon + count
                    Row(children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${widget.itemCount}',
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
                        widget.itemCount == 1
                            ? '1 item in cart'
                            : '${widget.itemCount} items in cart',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ]),
                    // Total + arrow
                    Row(children: [
                      Text(
                        '₹${widget.total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white, size: 13),
                    ]),
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

// ─── PREMIUM BOTTOM BAR ───────────────────────────────────────────
class _PremiumBottomBar extends StatelessWidget {
  final int currentIndex;
  final int cartCount;
  final ValueChanged<int> onTap;
  final List<AnimationController> controllers;
  final bool hasFloatingCart;

  const _PremiumBottomBar({
    required this.currentIndex,
    required this.cartCount,
    required this.onTap,
    required this.controllers,
    required this.hasFloatingCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              _tab(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
              _tab(1, Icons.restaurant_menu_outlined,
                  Icons.restaurant_menu_rounded, 'Menu'),
              _cartTab(),
              _tab(3, Icons.receipt_long_outlined, Icons.receipt_long_rounded,
                  'Orders'),
              _tab(4, Icons.person_outline_rounded, Icons.person_rounded,
                  'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(int idx, IconData icon, IconData activeIcon, String label) {
    final active = currentIndex == idx;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(idx),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? const Color(AppColors.primary).withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(26),
              ),
              child: AnimatedScale(
                scale: active ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  active ? activeIcon : icon,
                  size: 22,
                  color: active
                      ? const Color(AppColors.primary)
                      : const Color(AppColors.textHint),
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active
                    ? const Color(AppColors.primary)
                    : const Color(AppColors.textHint),
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartTab() {
    final active = currentIndex == 2;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(AppColors.primary)
                        : const Color(AppColors.primary).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: AnimatedScale(
                    scale: active ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.shopping_cart_rounded,
                      size: 22,
                      color: active
                          ? Colors.white
                          : const Color(AppColors.primary),
                    ),
                  ),
                ),
                if (cartCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: AnimatedScale(
                      scale: cartCount > 0 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: Color(AppColors.accent),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            cartCount > 9 ? '9+' : '$cartCount',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active
                    ? const Color(AppColors.primary)
                    : const Color(AppColors.textHint),
              ),
              child: const Text('Cart'),
            ),
          ],
        ),
      ),
    );
  }
}

void showSnackTop(BuildContext context, String message,
    {bool isError = false}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(message,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor:
          isError ? const Color(AppColors.error) : const Color(0xFF1A1A1A),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).size.height - 160,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
}
