
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with TickerProviderStateMixin {
  Product? _product;
  bool _loading = true;
  ProductSize? _selectedSize;
  CrustType? _selectedCrust;
  final Set<int> _selectedToppingIds = {};
  int _quantity = 1;

  late AnimationController _addController;
  late Animation<double> _addScale;

  @override
  void initState() {
    super.initState();
    _addController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _addScale = Tween<double>(begin: 1.0, end: 0.93).animate(
        CurvedAnimation(parent: _addController, curve: Curves.easeInOut));
    _load();
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await ApiService.getProduct(widget.productId);
      setState(() {
        _product = p;
        _selectedSize = p.sizes.isNotEmpty ? p.sizes.first : null;
        _selectedCrust = p.crusts.isNotEmpty ? p.crusts.first : null;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  double get _totalPrice {
    if (_product == null || _selectedSize == null) return 0;
    double price = _selectedSize!.price;
    if (_selectedCrust != null) price += _selectedCrust!.extraPrice;
    for (final id in _selectedToppingIds) {
      final t = _product!.toppings.firstWhere(
        (t) => t.id == id,
        orElse: () =>
            Topping(id: 0, name: '', price: 0, isVeg: true, isAvailable: true),
      );
      price += t.price;
    }
    return price * _quantity;
  }

  Future<void> _addToCart() async {
    if (_product == null || _selectedSize == null) return;
    HapticFeedback.mediumImpact();
    await _addController.forward();
    await _addController.reverse();

    if (!mounted) return;
    final cart = context.read<CartProvider>();
    final selectedToppings = _product!.toppings
        .where((t) => _selectedToppingIds.contains(t.id))
        .toList();
    cart.addItem(CartItem(
      product: _product!,
      size: _selectedSize!,
      crust: _selectedCrust,
      selectedToppings: selectedToppings,
      quantity: _quantity,
    ));
    if (!mounted) return;
    AppToast.success(context, '${_product!.name} added to cart!');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
            child: PizzaSpinner(size: 40)),
      );
    }
    if (_product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Product')),
        body: const Center(child: Text('Product not found')),
      );
    }

    final p = _product!;
    return Scaffold(
      backgroundColor: const Color(AppColors.background),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                stretch: true,
                backgroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      PizzaNetImage(url: p.imageUrl, fit: BoxFit.cover),
                      // Bottom gradient
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 100,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Color(AppColors.background),
                                Colors.transparent
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 12,
                        left: 12,
                        child: VegBadge(isVeg: p.isVeg),
                      ),
                      if (p.isFeatured)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 8,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(AppColors.accent),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded,
                                      color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text('Featured',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                ]),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  color: const Color(AppColors.background),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800)),
                                  if (p.categoryName != null)
                                    Text(p.categoryName!,
                                        style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 13)),
                                ],
                              ),
                            ),
                            if (p.avgRating != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(AppColors.warning)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          color: Color(AppColors.warning),
                                          size: 14),
                                      const SizedBox(width: 4),
                                      Text(p.avgRating!.toStringAsFixed(1),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13)),
                                      if (p.reviewCount != null)
                                        Text(' (${p.reviewCount})',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500)),
                                    ]),
                              ),
                          ],
                        ),
                      ),
                      if (p.description != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                          child: Text(p.description!,
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                  height: 1.5)),
                        ),

                      // Sizes
                      if (p.sizes.isNotEmpty) ...[
                        _sectionTitle('Choose Size', Icons.straighten_rounded),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: p.sizes.map((size) {
                              final selected = _selectedSize?.id == size.id;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _selectedSize = size);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? const Color(AppColors.primary)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: selected
                                            ? const Color(AppColors.primary)
                                            : Colors.grey.shade200,
                                        width: 1.5,
                                      ),
                                      boxShadow: selected
                                          ? [
                                              BoxShadow(
                                                  color: const Color(
                                                          AppColors.primary)
                                                      .withValues(alpha: 0.25),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3)),
                                            ]
                                          : null,
                                    ),
                                    child: Column(children: [
                                      Text(size.sizeName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: selected
                                                ? Colors.white
                                                : const Color(
                                                    AppColors.textPrimary),
                                          )),
                                      const SizedBox(height: 3),
                                      Text('₹${size.price.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 17,
                                            color: selected
                                                ? Colors.white
                                                : const Color(
                                                    AppColors.primary),
                                          )),
                                    ]),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],

                      // Crusts
                      if (p.crusts.isNotEmpty) ...[
                        _sectionTitle('Choose Crust', Icons.circle_outlined),
                        SizedBox(
                          height: 50,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: p.crusts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (ctx, i) {
                              final c = p.crusts[i];
                              final sel = _selectedCrust?.id == c.id;
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedCrust = c);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 11),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? const Color(AppColors.primary)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(
                                        color: sel
                                            ? const Color(AppColors.primary)
                                            : Colors.grey.shade200),
                                    boxShadow: sel
                                        ? [
                                            BoxShadow(
                                                color: const Color(
                                                        AppColors.primary)
                                                    .withValues(alpha: 0.25),
                                                blurRadius: 8)
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(c.name,
                                            style: TextStyle(
                                              color: sel
                                                  ? Colors.white
                                                  : const Color(
                                                      AppColors.textPrimary),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            )),
                                        if (c.extraPrice > 0) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                              '+₹${c.extraPrice.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                  color: sel
                                                      ? Colors.white70
                                                      : Colors.grey.shade500,
                                                  fontSize: 11)),
                                        ],
                                      ]),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // Toppings
                      if (p.toppings.isNotEmpty) ...[
                        _sectionTitle(
                            'Add Toppings', Icons.add_circle_outline_rounded),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: p.toppings.map((t) {
                              final sel = _selectedToppingIds.contains(t.id);
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    sel
                                        ? _selectedToppingIds.remove(t.id)
                                        : _selectedToppingIds.add(t.id);
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? const Color(AppColors.primary)
                                            .withValues(alpha: 0.08)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: sel
                                          ? const Color(AppColors.primary)
                                          : Colors.grey.shade200,
                                      width: sel ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (sel)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 5),
                                            child: Icon(
                                                Icons.check_circle_rounded,
                                                size: 14,
                                                color:
                                                    Color(AppColors.primary)),
                                          ),
                                        VegBadge(isVeg: t.isVeg),
                                        const SizedBox(width: 6),
                                        Text(t.name,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: sel
                                                  ? const Color(
                                                      AppColors.primary)
                                                  : const Color(
                                                      AppColors.textPrimary),
                                            )),
                                        const SizedBox(width: 4),
                                        Text('+₹${t.price.toStringAsFixed(0)}',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500)),
                                      ]),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Bottom bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -4))
                ],
              ),
              child: Row(
                children: [
                  // Quantity stepper
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(AppColors.background),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _qBtn(Icons.remove_rounded, () {
                        if (_quantity > 1) setState(() => _quantity--);
                      }),
                      SizedBox(
                        width: 36,
                        child: Text('$_quantity',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                      _qBtn(
                          Icons.add_rounded, () => setState(() => _quantity++)),
                    ]),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ScaleTransition(
                      scale: _addScale,
                      child: ElevatedButton(
                        onPressed: _addToCart,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Add to Cart',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 10),
                            // Fixed width container for price to prevent layout shifts
                            Container(
                              constraints: const BoxConstraints(
                                  minWidth: 50), // Fixed minimum width
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '₹${_totalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 14),
                                // Ensure text doesn't wrap
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
        child: Row(children: [
          Icon(icon, size: 18, color: const Color(AppColors.primary)),
          const SizedBox(width: 8),
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _qBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(AppColors.primary), size: 20),
        ),
      );
}
