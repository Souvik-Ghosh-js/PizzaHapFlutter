
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';

// ═══════════════════════════════════════════
// NOTIFICATIONS SCREEN
// ═══════════════════════════════════════════

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<NotificationProvider>();
    return Scaffold(
      backgroundColor: const Color(AppColors.background),
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (prov.unreadCount > 0)
            TextButton(
              onPressed: () => prov.markAllRead(),
              child: const Text('Mark all read',
                  style: TextStyle(
                      color: Color(AppColors.primary),
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: prov.loading
          ? const Center(
              child: PizzaSpinner(size: 40))
          : prov.notifications.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No notifications yet')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: prov.notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final n = prov.notifications[i];
                    return GestureDetector(
                      onTap: () {
                        if (!n.isRead) {
                          ApiService.markNotificationRead(n.id).then((_) {
                            prov.load();
                          }).catchError((_) {});
                        }
                        if (n.orderId != null) {
                          Navigator.pushNamed(context, '/order-detail', arguments: n.orderId);
                        } else if (n.type == 'order') {
                          // Try to extract order ID from notification message or payload if possible.
                          // However, we rely on the backend now. 
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: n.isRead
                              ? Colors.white
                              : const Color(AppColors.primary).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: n.isRead
                                ? Colors.grey.shade100
                                : const Color(AppColors.primary).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(AppColors.primary)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                  child: Icon(_notifTypeIcon(n.type),
                                      size: 18,
                                      color: const Color(AppColors.primary))),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n.title,
                                      style: TextStyle(
                                          fontWeight: n.isRead
                                              ? FontWeight.w600
                                              : FontWeight.w800,
                                          fontSize: 14)),
                                  const SizedBox(height: 3),
                                  Text(n.message,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                          height: 1.4)),
                                ],
                              ),
                            ),
                            if (!n.isRead)
                              Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      color: Color(AppColors.primary),
                                      shape: BoxShape.circle)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  IconData _notifTypeIcon(String? type) {
    switch (type) {
      case 'order':
        return Icons.receipt_long_rounded;
      case 'payment':
        return Icons.payment_rounded;
      case 'promo':
        return Icons.local_offer_rounded;
      case 'refund':
        return Icons.assignment_return_rounded;
      case 'coins':
        return Icons.stars_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}

// ═══════════════════════════════════════════
// COUPONS SCREEN
// ═══════════════════════════════════════════

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});
  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  List<Coupon> _coupons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _coupons = await ApiService.getCoupons();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(AppColors.background),
        appBar: AppBar(title: const Text('Available Coupons')),
        body: _loading
            ? const Center(
                child:
                    PizzaSpinner(size: 40))
            : _coupons.isEmpty
                ? const EmptyState(
                    icon: Icons.local_offer_outlined,
                    title: 'No active coupons',
                    subtitle: 'Check back later for offers!')
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _coupons.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) => _CouponCard(coupon: _coupons[i]),
                  ),
      );
}

class _CouponCard extends StatelessWidget {
  final Coupon coupon;
  const _CouponCard({required this.coupon});

  void _copyAndUse(BuildContext context) {
    // Copy to clipboard
    Clipboard.setData(ClipboardData(text: coupon.code));
    // Navigate to cart with the coupon pre-filled
    Navigator.pushNamed(context, '/cart',
        arguments: {'autoCoupon': coupon.code});
    AppToast.success(context, 'Coupon applied to cart!');
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent strip
              Container(
                width: 8,
                decoration: const BoxDecoration(
                  color: Color(AppColors.primary),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              // Dashed separator
              Container(width: 1, color: Colors.grey.shade200),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Coupon code chip - tap to copy
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: coupon.code));
                              AppToast.success(context,
                                  '"${coupon.code}" copied to clipboard!');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(AppColors.primary)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(AppColors.primary)
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(coupon.code,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: Color(AppColors.primary),
                                            letterSpacing: 0.5)),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.copy_rounded,
                                        size: 13,
                                        color: Color(AppColors.primary)),
                                  ]),
                            ),
                          ),
                          const Spacer(),
                          // Discount badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(AppColors.success)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(coupon.displayDiscount,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: Color(AppColors.success))),
                          ),
                        ],
                      ),
                      if (coupon.description != null) ...[
                        const SizedBox(height: 6),
                        Text(coupon.description!,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ],
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.info_outline_rounded,
                            size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                            'Min. order ₹${coupon.minOrderValue.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                      ]),
                      const SizedBox(height: 10),
                      // Apply to cart button
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () => _copyAndUse(context),
                          icon:
                              const Icon(Icons.shopping_cart_rounded, size: 14),
                          label: const Text('Apply to Cart',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
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
      );
}

// ═══════════════════════════════════════════
// SUPPORT SCREEN
// ═══════════════════════════════════════════

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  List<SupportTicket> _tickets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _tickets = await ApiService.getTickets();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _createTicket() {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String category = 'other';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text('New Support Ticket',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              const Text('Category',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: category,
                    isExpanded: true,
                    items: [
                      'order_issue',
                      'payment',
                      'refund',
                      'delivery',
                      'other'
                    ]
                        .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(fontSize: 14))))
                        .toList(),
                    onChanged: (v) => setModalState(() => category = v!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Subject',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              TextFormField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(hintText: 'Brief subject')),
              const SizedBox(height: 12),
              const Text('Message',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              TextFormField(
                  controller: messageCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      hintText: 'Describe your issue...')),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (subjectCtrl.text.isEmpty || messageCtrl.text.isEmpty) {
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    await ApiService.createTicket({
                      'subject': subjectCtrl.text,
                      'message': messageCtrl.text,
                      'category': category,
                    });
                    if (!mounted) return;
                    AppToast.success(context, 'Support ticket created!');
                    _load();
                  } on ApiException catch (e) {
                    if (!mounted) return;
                    AppToast.error(context, e.message);
                  }
                },
                child: const Text('Submit Ticket'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(AppColors.background),
        appBar: AppBar(title: const Text('Support')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createTicket,
          backgroundColor: const Color(AppColors.primary),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('New Ticket',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        body: _loading
            ? const Center(
                child:
                    PizzaSpinner(size: 40))
            : _tickets.isEmpty
                ? EmptyState(
                    icon: Icons.headset_mic_outlined,
                    title: 'No support tickets',
                    subtitle:
                        "Need help? Create a ticket and we'll respond shortly.",
                    buttonText: 'Create Ticket',
                    onButton: _createTicket,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _tickets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final t = _tickets[i];
                      return GestureDetector(
                        onTap: () => Navigator.pushNamed(
                                context, '/ticket-detail',
                                arguments: t.id)
                            .then((_) => _load()),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8)
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(AppColors.primary)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.local_offer_rounded,
                                    color: Color(AppColors.primary), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t.subject,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text(t.ticketNumber,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _statusBadge(t.status),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      );

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case 'open':
        color = Colors.blue;
        break;
      case 'in_progress':
        color = const Color(AppColors.warning);
        break;
      case 'resolved':
        color = const Color(AppColors.success);
        break;
      case 'closed':
        color = Colors.grey;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(status.replaceAll('_', ' '),
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ═══════════════════════════════════════════
// TICKET DETAIL SCREEN
// ═══════════════════════════════════════════

class TicketDetailScreen extends StatefulWidget {
  final int ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});
  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  SupportTicket? _ticket;
  bool _loading = true;
  final _replyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _replying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final t = await ApiService.getTicket(widget.ticketId);
      if (mounted) {
        setState(() {
          _ticket = t;
          _loading = false;
        });
      }
      // scroll to bottom after messages load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reply() async {
    if (_replyCtrl.text.trim().isEmpty) return;
    setState(() => _replying = true);
    try {
      await ApiService.replyToTicket(widget.ticketId, _replyCtrl.text.trim());
      _replyCtrl.clear();
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _replying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(
              child:
                  PizzaSpinner(size: 40)));
    }
    if (_ticket == null) {
      return const Scaffold(body: Center(child: Text('Ticket not found')));
    }
    final t = _ticket!;

    return Scaffold(
      backgroundColor: const Color(AppColors.background),
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.ticketNumber,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          Text(t.subject,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _statusColor(t.status).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(t.status.replaceAll('_', ' '),
                  style: TextStyle(
                      color: _statusColor(t.status),
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                ...t.messages.map((m) => _MessageBubble(message: m)),
              ],
            ),
          ),
          if (t.status != 'closed')
            Container(
              padding: EdgeInsets.fromLTRB(
                  16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -2))
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Write a reply...',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      ),
                      onSubmitted: (_) => _reply(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _replying ? null : _reply,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Color(AppColors.primary),
                        shape: BoxShape.circle,
                      ),
                      child: _replying
                          ? const Center(
                              child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: PizzaSpinner(size: 20, color: Colors.white)))
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.blue;
      case 'in_progress':
        return const Color(AppColors.warning);
      case 'resolved':
        return const Color(AppColors.success);
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final SupportMessage message;
  const _MessageBubble({required this.message});

  bool get _isUser => message.senderRole == 'user';

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment:
              _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!_isUser)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text('Support Agent',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500)),
              ),
            Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _isUser ? const Color(AppColors.primary) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(_isUser ? 16 : 4),
                  bottomRight: Radius.circular(_isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)
                ],
              ),
              child: Text(message.message,
                  style: TextStyle(
                      color: _isUser
                          ? Colors.white
                          : const Color(AppColors.textPrimary),
                      fontSize: 14,
                      height: 1.4)),
            ),
          ],
        ),
      );
}

// ═══════════════════════════════════════════
// REFUNDS SCREEN
// ═══════════════════════════════════════════

class RefundsScreen extends StatefulWidget {
  const RefundsScreen({super.key});
  @override
  State<RefundsScreen> createState() => _RefundsScreenState();
}

class _RefundsScreenState extends State<RefundsScreen> {
  List<dynamic> _refunds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _refunds = await ApiService.getMyRefunds();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(AppColors.background),
        appBar: AppBar(title: const Text('My Refunds')),
        body: _loading
            ? const Center(
                child:
                    PizzaSpinner(size: 40))
            : _refunds.isEmpty
                ? const EmptyState(
                    icon: Icons.currency_rupee_rounded,
                    title: 'No refund requests',
                    subtitle: 'Your refund requests will appear here')
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _refunds.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final r = _refunds[i];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8)
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Order #${r['order_number'] ?? '-'}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _refundStatusColor(r['status'])
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(r['status'] ?? '',
                                      style: TextStyle(
                                          color:
                                              _refundStatusColor(r['status']),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('₹${r['amount']}',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(AppColors.primary))),
                            const SizedBox(height: 4),
                            Text(r['reason'] ?? '',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey.shade600)),
                          ],
                        ),
                      );
                    },
                  ),
      );

  Color _refundStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return const Color(AppColors.warning);
      case 'processing':
        return Colors.blue;
      case 'completed':
        return const Color(AppColors.success);
      case 'failed':
        return const Color(AppColors.error);
      default:
        return Colors.grey;
    }
  }
}
