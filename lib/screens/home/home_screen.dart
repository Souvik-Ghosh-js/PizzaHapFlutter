import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/providers.dart';
import '../../config/app_config.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _headerFade =
        CurvedAnimation(parent: _headerController, curve: Curves.easeOut);
    _headerController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final menu = context.read<MenuProvider>();
    final auth = context.read<AuthProvider>();
    final orders = context.read<OrderProvider>();

    await Future.wait([
      menu.loadHomeData(),
      auth.refreshUser(),
      orders.loadActiveOrder(),
    ]);
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final menu = context.watch<MenuProvider>();
    final cart = context.watch<CartProvider>();
    final firstName = auth.user?.name.split(' ').first ?? 'there';

    return Scaffold(
      backgroundColor: const Color(AppColors.background),
      body: RefreshIndicator(
        color: const Color(AppColors.primary),
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 130,
              floating: false,
              pinned: true,
              snap: false,
              elevation: 0,
              backgroundColor: const Color(AppColors.primaryDark),
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(AppColors.primaryDark),
                        Color(AppColors.primary)
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -20,
                        right: -20,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 12,
                          left: 20,
                          right: 20,
                          bottom: 10,
                        ),
                        child: FadeTransition(
                          opacity: _headerFade,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hey $firstName! 🤚',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (cart.selectedLocationName != null) ...[
                                      const SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: () => Navigator.pushNamed(
                                            context, '/branch-selection'),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                                Icons.location_on_rounded,
                                                color: Colors.white70,
                                                size: 13),
                                            const SizedBox(width: 3),
                                            Flexible(
                                              child: Text(
                                                cart.selectedLocationName!,
                                                style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w600),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const Icon(
                                                Icons
                                                    .keyboard_arrow_down_rounded,
                                                color: Colors.white54,
                                                size: 14),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    Navigator.pushNamed(context, '/coins'),
                                child: Container(
                                  height:
                                      38, // Same height as notification container
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical:
                                          0), // Removed vertical padding since height is fixed
                                  decoration: BoxDecoration(
                                    color:
                                        const Color.fromARGB(255, 226, 226, 226)
                                            .withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(
                                        11), // Same border radius as notification
                                    border: Border.all(
                                        color: const Color.fromARGB(
                                                255, 255, 255, 255)
                                            .withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.stars_rounded,
                                          color:
                                              Color.fromARGB(255, 237, 191, 7),
                                          size: 15),
                                      const SizedBox(width: 5),
                                      Text(
                                        '${auth.user?.coinBalance ?? 0} Coins',
                                        style: const TextStyle(
                                          color: Color.fromARGB(
                                              255, 255, 255, 255),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Notifications
                              Consumer<NotificationProvider>(
                                builder: (_, notif, __) => GestureDetector(
                                  onTap: () => Navigator.pushNamed(
                                      context, '/notifications'),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.18),
                                          borderRadius:
                                              BorderRadius.circular(11),
                                        ),
                                        child: const Icon(
                                            Icons.notifications_outlined,
                                            color: Colors.white,
                                            size: 20),
                                      ),
                                      if (notif.unreadCount > 0)
                                        Positioned(
                                          top: -3,
                                          right: -3,
                                          child: Container(
                                            width: 16,
                                            height: 16,
                                            decoration: const BoxDecoration(
                                              color: Color(AppColors.accent),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                  '${notif.unreadCount}',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w800)),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Container(
                  color: Colors.white,
                  height: 52,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/menu'),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(AppColors.background),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Icon(Icons.search_rounded,
                              color: Colors.grey.shade400, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Search pizzas, sides, drinks...',
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 100),
              sliver: SliverToBoxAdapter(
                child: menu.loading
                    ? const _HomeShimmer()
                    : _HomeContent(menu: menu, cart: cart, auth: auth),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final MenuProvider menu;
  final CartProvider cart;
  final AuthProvider auth;
  const _HomeContent(
      {required this.menu, required this.cart, required this.auth});

  @override
  Widget build(BuildContext context) {
    final activeOrder = context.watch<OrderProvider>().activeOrder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // ── Active Order Banner ──────────────────────────────
        if (activeOrder != null) ...[
          _ActiveOrderBanner(order: activeOrder),
          const SizedBox(height: 16),
        ],
        const _PromoBannerSlider(),
        const SizedBox(height: 20),

        if (menu.categories.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionHeader(
                title: 'Categories',
                onSeeAll: () => Navigator.pushNamed(context, '/menu')),
          ),
          const SizedBox(height: 12),
          _CategoriesRow(categories: menu.categories),
          const SizedBox(height: 24),
        ],
        if (menu.featuredProducts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionHeader(
              title: 'Featured',
              titleIcon: Icons.local_fire_department_rounded,
              titleIconColor: Colors.deepOrange,
              subtitle: 'Our best-sellers',
              onSeeAll: () => Navigator.pushNamed(context, '/menu'),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cardW = constraints.maxWidth * 0.47;
              return SizedBox(
                height: cardW * 1.55,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: menu.featuredProducts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (ctx, i) {
                    final p = menu.featuredProducts[i];
                    return SizedBox(
                      width: cardW,
                      child: ProductCard(
                        product: p,
                        onTap: () => Navigator.pushNamed(context, '/product',
                            arguments: p.id),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: SectionHeader(
            title: 'Quick Actions',
            titleIcon: Icons.bolt_rounded,
            titleIconColor: Colors.amber,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _QuickAction(
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFF3B82F6),
                label: 'My Orders',
                onTap: () => Navigator.pushNamed(context, '/orders'),
              ),
              const SizedBox(width: 10),
              _QuickAction(
                icon: Icons.local_offer_rounded,
                color: const Color(AppColors.accent),
                label: 'Coupons',
                onTap: () => Navigator.pushNamed(context, '/coupons'),
              ),
              const SizedBox(width: 10),
              _QuickAction(
                icon: Icons.headset_mic_rounded,
                color: const Color(AppColors.success),
                label: 'Support',
                onTap: () => Navigator.pushNamed(context, '/support'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // "Developed by GOBT" footer
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Developed by GOBT',
              style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── PROMO BANNER SLIDER ─────────────────────────────────────────

class _PromoBannerSlider extends StatefulWidget {
  const _PromoBannerSlider();
  @override
  State<_PromoBannerSlider> createState() => _PromoBannerSliderState();
}

class _PromoBannerSliderState extends State<_PromoBannerSlider> {
  final _pageCtrl = PageController(viewportFraction: 0.92);
  int _currentPage = 0;
  Timer? _timer;

  static const _banners = [
    _BannerData(
      gradient: [Color(0xFF991515), Color(AppColors.accent)],
      icon: Icons.local_shipping_rounded,
      badge: 'Special Offer',
      title: 'Free delivery on\norders above ₹300!',
    ),
    _BannerData(
      gradient: [Color(0xFF1A1A8C), Color(0xFF4F6DEA)],
      icon: Icons.auto_awesome_rounded,
      badge: 'New Arrivals',
      title: 'Try our new\nsignature pizzas!',
    ),
    _BannerData(
      gradient: [Color(0xFF166534), Color(0xFF16A34A)],
      icon: Icons.eco_rounded,
      badge: 'Healthy Choice',
      title: 'Fresh veg pizzas\nwith extra toppings!',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      _pageCtrl.animateToPage(
        (_currentPage + 1) % _banners.length,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 145,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (ctx, i) => _BannerCard(data: _banners[i]),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _banners.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentPage == i ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentPage == i
                    ? const Color(AppColors.primary)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BannerData {
  final List<Color> gradient;
  final IconData icon;
  final String badge, title;
  const _BannerData(
      {required this.gradient,
      required this.icon,
      required this.badge,
      required this.title});
}

class _BannerCard extends StatelessWidget {
  final _BannerData data;
  const _BannerCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
            colors: data.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        boxShadow: [
          BoxShadow(
              color: data.gradient.first.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // BG circle
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 100, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    data.badge,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  data.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      height: 1.3),
                ),
              ],
            ),
          ),
          Positioned(
            right: 20,
            top: 0,
            bottom: 0,
            child: Icon(data.icon,
                color: Colors.white.withValues(alpha: 0.9), size: 72),
          ),
        ],
      ),
    );
  }
}

// ─── CATEGORIES ROW ──────────────────────────────────────────────

class _CategoriesRow extends StatelessWidget {
  final List<Category> categories;
  const _CategoriesRow({required this.categories});

  IconData _icon(String name) {
    final n = name.toLowerCase();
    if (n.contains('pizza')) {
      return Icons.local_pizza_rounded;
    }
    if (n.contains('pasta') || n.contains('noodle')) {
      return Icons.ramen_dining_rounded;
    }
    if (n.contains('burger')) {
      return Icons.lunch_dining_rounded;
    }
    if (n.contains('dessert') || n.contains('sweet')) {
      return Icons.cake_rounded;
    }
    if (n.contains('drink') || n.contains('bev')) {
      return Icons.local_drink_rounded;
    }
    if (n.contains('salad')) {
      return Icons.eco_rounded;
    }
    if (n.contains('side') || n.contains('starter')) {
      return Icons.restaurant_rounded;
    }
    return Icons.restaurant_menu_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final c = categories[i];
          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/menu', arguments: c.id),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 8)
                    ],
                  ),
                  child: c.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: PizzaNetImage(
                              url: c.imageUrl!, width: 58, height: 58),
                        )
                      : Icon(_icon(c.name),
                          size: 28, color: const Color(AppColors.primary)),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 64,
                  child: Text(
                    c.name,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── QUICK ACTION ────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon,
      required this.color,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SHIMMER ─────────────────────────────────────────────────────

class _HomeShimmer extends StatelessWidget {
  const _HomeShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade50,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                height: 145,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20))),
            const SizedBox(height: 24),
            Container(
                height: 16,
                width: 100,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 12),
            Row(
                children: List.generate(
                    5,
                    (_) => Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Column(children: [
                            Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16))),
                            const SizedBox(height: 6),
                            Container(
                                width: 48,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(5))),
                          ]),
                        ))),
            const SizedBox(height: 24),
            Container(
                height: 16,
                width: 130,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 12),
            Row(
                children: List.generate(
                    2,
                    (_) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: AspectRatio(
                              aspectRatio: 0.75,
                              child: Container(
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16))),
                            ),
                          ),
                        ))),
          ],
        ),
      ),
    );
  }
}

// ─── ACTIVE ORDER BANNER ─────────────────────────────────────────

class _ActiveOrderBanner extends StatefulWidget {
  final Order order;
  const _ActiveOrderBanner({required this.order});
  @override
  State<_ActiveOrderBanner> createState() => _ActiveOrderBannerState();
}

class _ActiveOrderBannerState extends State<_ActiveOrderBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(_pulse);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  // Map status -> (label, icon, gradient colors)
  (String, IconData, List<Color>) _statusInfo(String status) {
    switch (status) {
      case 'pending':
        return (
          'Order Received',
          Icons.hourglass_top_rounded,
          [const Color(0xFFB45309), const Color(0xFFF59E0B)]
        );
      case 'confirmed':
        return (
          'Order Confirmed',
          Icons.check_circle_outline_rounded,
          [const Color(0xFF1D4ED8), const Color(0xFF3B82F6)]
        );
      case 'preparing':
        return (
          'Being Prepared',
          Icons.local_fire_department_rounded,
          [const Color(0xFF991B1B), const Color(0xFFEF4444)]
        );
      case 'out_for_delivery':
        return (
          'Out for Delivery',
          Icons.delivery_dining_rounded,
          [const Color(0xFF065F46), const Color(0xFF10B981)]
        );
      default:
        return (
          'Processing',
          Icons.info_outline_rounded,
          [const Color(0xFF4B5563), const Color(0xFF6B7280)]
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final (statusLabel, statusIcon, gradColors) = _statusInfo(order.status);

    // Summarize items (up to 2 names + count)
    final itemNames = order.items.take(2).map((i) => i.productName).join(', ');
    final extraCount = order.items.length - 2;
    final itemSummary =
        extraCount > 0 ? '$itemNames +$extraCount more' : itemNames;

    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, '/order-detail', arguments: order.id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradColors.last.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Decorative bg circle
            Positioned(
              right: -24,
              top: -24,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  // Pulsing status icon
                  ScaleTransition(
                    scale: _pulseAnim,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(statusIcon, color: Colors.white, size: 28),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Order info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                statusLabel,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          order.orderNumber,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900),
                        ),
                        if (itemSummary.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            itemSummary,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Amount + arrow
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₹${order.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_ios_rounded,
                            color: Colors.white, size: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
