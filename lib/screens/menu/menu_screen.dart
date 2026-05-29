import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/providers.dart';
import '../../config/app_config.dart';
import '../../widgets/widgets.dart';

class MenuScreen extends StatefulWidget {
  final int? initialCategoryId;
  const MenuScreen({super.key, this.initialCategoryId});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  int _vegMode = 0;
  int? _selectedCategoryId;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _animController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final menu = context.read<MenuProvider>();
      if (menu.categories.isEmpty) menu.loadHomeData();
      menu.loadProducts(categoryId: _selectedCategoryId);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  bool? get _vegFilter {
    if (_vegMode == 1) return true;
    if (_vegMode == 2) return false;
    return null;
  }

  void _applyFilters() {
    context.read<MenuProvider>().loadProducts(
          categoryId: _selectedCategoryId,
          isVeg: _vegFilter,
          search:
              _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        );
  }

  void _cycleVegMode() {
    HapticFeedback.selectionClick();
    setState(() => _vegMode = (_vegMode + 1) % 3);
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<MenuProvider>();

    return Scaffold(
      backgroundColor: const Color(AppColors.background),
      appBar: AppBar(
        title: const Text('Menu'),
        automaticallyImplyLeading: ModalRoute.of(context)?.canPop ?? false,
        actions: [
          GestureDetector(
            onTap: _cycleVegMode,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _vegMode == 0
                    ? Colors.grey.shade100
                    : _vegMode == 1
                        ? const Color(AppColors.vegGreen).withValues(alpha: 0.12)
                        : const Color(AppColors.nonVegRed).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _vegMode == 0
                      ? Colors.grey.shade300
                      : _vegMode == 1
                          ? const Color(AppColors.vegGreen)
                          : const Color(AppColors.nonVegRed),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _VegIndicator(isVeg: _vegMode != 2),
                const SizedBox(width: 6),
                Text(
                  _vegMode == 0
                      ? 'All'
                      : _vegMode == 1
                          ? 'Veg'
                          : 'Non-Veg',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _vegMode == 0
                        ? Colors.grey.shade600
                        : _vegMode == 1
                            ? const Color(AppColors.vegGreen)
                            : const Color(AppColors.nonVegRed),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: const CartFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search menu...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _applyFilters();
                          setState(() {});
                        })
                    : null,
              ),
              onChanged: (_) {
                setState(() {});
                Future.delayed(
                    const Duration(milliseconds: 400), _applyFilters);
              },
            ),
          ),
          // Category chips
          if (menu.categories.isNotEmpty)
            SizedBox(
              height: 54,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                itemCount: menu.categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    return _CategoryChip(
                      label: 'All',
                      selected: _selectedCategoryId == null,
                      onTap: () {
                        setState(() => _selectedCategoryId = null);
                        _applyFilters();
                      },
                    );
                  }
                  final c = menu.categories[i - 1];
                  final selected = _selectedCategoryId == c.id;
                  return _CategoryChip(
                    label: c.name,
                    selected: selected,
                    onTap: () {
                      setState(
                          () => _selectedCategoryId = selected ? null : c.id);
                      _applyFilters();
                    },
                  );
                },
              ),
            ),
          // Products grid
          Expanded(
            child: menu.loading
                ? _buildShimmer()
                : menu.products.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No items found',
                        subtitle: 'Try adjusting your filters',
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.70,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: menu.products.length,
                        itemBuilder: (ctx, i) {
                          final p = menu.products[i];
                          return AnimatedProductCard(
                            index: i,
                            child: ProductCard(
                              product: p,
                              onTap: () => Navigator.pushNamed(
                                  context, '/product',
                                  arguments: p.id),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() => GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.70,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: Colors.grey.shade200,
          highlightColor: Colors.grey.shade50,
          child: Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16))),
        ),
      );
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(AppColors.primary) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(AppColors.primary)
                : Colors.grey.shade300,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: const Color(AppColors.primary).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color:
                selected ? Colors.white : const Color(AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _VegIndicator extends StatelessWidget {
  final bool isVeg;
  const _VegIndicator({required this.isVeg});

  @override
  Widget build(BuildContext context) {
    final color = isVeg
        ? const Color(AppColors.vegGreen)
        : const Color(AppColors.nonVegRed);
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(2)),
      child: Center(
          child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle))),
    );
  }
}

// Animated wrapper for product cards staggered entrance
class AnimatedProductCard extends StatefulWidget {
  final int index;
  final Widget child;
  const AnimatedProductCard(
      {super.key, required this.index, required this.child});
  @override
  State<AnimatedProductCard> createState() => _AnimatedProductCardState();
}

class _AnimatedProductCardState extends State<AnimatedProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: 40 * (widget.index % 6)), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}
