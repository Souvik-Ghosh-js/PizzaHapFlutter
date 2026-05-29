
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../config/app_config.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _tabs = [
    null,
    'pending',
    'confirmed',
    'preparing',
    'delivered',
    'cancelled'
  ];
  final _tabLabels = [
    'All',
    'Pending',
    'Confirmed',
    'Preparing',
    'Delivered',
    'Cancelled'
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        context.read<OrderProvider>().loadOrders(status: _tabs[_tabCtrl.index]);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().loadOrders();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();
    return Scaffold(
      backgroundColor: const Color(AppColors.background),
      appBar: AppBar(
        title: const Text('My Orders'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          labelColor: const Color(AppColors.primary),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(AppColors.primary),
          tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      floatingActionButton: const CartFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: TabBarView(
        controller: _tabCtrl,
        children: List.generate(_tabs.length, (_) => _buildList(orders)),
      ),
    );
  }

  Widget _buildList(OrderProvider orders) {
    if (orders.loading) {
      return const Center(
          child: PizzaSpinner(size: 40));
    }
    if (orders.orders.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No orders yet',
        subtitle: 'Your order history will appear here',
      );
    }
    return RefreshIndicator(
      color: const Color(AppColors.primary),
      onRefresh: () => context
          .read<OrderProvider>()
          .loadOrders(status: _tabs[_tabCtrl.index]),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => _OrderCard(order: orders.orders[i]),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () =>
            Navigator.pushNamed(context, '/order-detail', arguments: order.id),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(order.orderNumber,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  OrderStatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(_formatDate(order.createdAt),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  if (order.locationName != null) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.location_on_outlined,
                        size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(order.locationName!,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                            order.deliveryType == 'delivery'
                                ? Icons.delivery_dining_outlined
                                : Icons.store_outlined,
                            size: 16,
                            color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                            order.deliveryType == 'delivery'
                                ? 'Delivery'
                                : 'Pickup',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: order.isPaid
                                ? const Color(AppColors.success)
                                    .withValues(alpha: 0.1)
                                : const Color(AppColors.warning)
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            order.isCOD
                                ? (order.isPaid ? 'COD ✓' : 'COD')
                                : (order.isPaid ? 'Paid' : 'Pending'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: order.isPaid
                                  ? const Color(AppColors.success)
                                  : const Color(AppColors.warning),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('₹${order.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Color(AppColors.primary))),
                    if (order.coinsEarned > 0)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.stars_rounded,
                            size: 11,
                            color: order.isDelivered
                                ? const Color(AppColors.coins)
                                : Colors.grey.shade500),
                        const SizedBox(width: 2),
                        Text(
                            order.isDelivered
                                ? '+${order.coinsEarned} coins'
                                : '${order.coinsEarned} to earn', // Short text for small space
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: order.isDelivered
                                    ? const Color(AppColors.coins)
                                    : Colors.grey.shade600)),
                      ]),
                  ]),
                ],
              ),
              if (order.canCancel) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pushNamed(
                            context, '/order-detail',
                            arguments: order.id),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 36)),
                        child: const Text('View Details'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _cancelDialog(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          foregroundColor: const Color(AppColors.error),
                          side: const BorderSide(color: Color(AppColors.error)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );

  void _cancelDialog(BuildContext context) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Reason for cancellation?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(hintText: 'Optional reason...'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep Order')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await context
                  .read<OrderProvider>()
                  .cancelOrder(order.id, reason: reasonCtrl.text);
              if (ok && context.mounted) {
                AppToast.success(context, 'Order cancelled');
                context.read<OrderProvider>().loadOrders();
              }
            },
            child: const Text('Cancel Order',
                style: TextStyle(color: Color(AppColors.error))),
          ),
        ],
      ),
    );
  }
}
