import 'package:pizzahap/widgets/app_loader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../config/app_config.dart';
import '../../models/models.dart';

class CoinsScreen extends StatefulWidget {
  const CoinsScreen({super.key});
  @override
  State<CoinsScreen> createState() => _CoinsScreenState();
}

class _CoinsScreenState extends State<CoinsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CoinsProvider>().load();
    });
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'earned':   return 'Earned';
      case 'redeemed': return 'Redeemed';
      case 'reverted': return 'Reverted';
      default: return type;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'earned':   return const Color(AppColors.success);
      case 'redeemed': return const Color(AppColors.primary);
      case 'reverted': return const Color(AppColors.error);
      default: return Colors.grey;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'earned':   return Icons.add_circle_outline;
      case 'redeemed': return Icons.shopping_cart_outlined;
      case 'reverted': return Icons.remove_circle_outline;
      default: return Icons.circle_outlined;
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    final coins = context.watch<CoinsProvider>();
    final balance = coins.balance;

    return Scaffold(
      backgroundColor: const Color(AppColors.background),
      appBar: AppBar(title: const Text('My Coins')),
      body: coins.loading
        ? const Center(child: PizzaSpinner(size: 40, color: Color(AppColors.coins)))
        : RefreshIndicator(
            color: const Color(AppColors.coins),
            onRefresh: () => context.read<CoinsProvider>().load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

                // ── Balance card ─────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: const Color(AppColors.coins).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Column(children: [
                    const Icon(Icons.stars_rounded, color: Colors.white, size: 44),
                    const SizedBox(height: 8),
                    Text('$balance', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white)),
                    const Text('Coins', style: TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                      child: Text('Worth ₹$balance', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── How it works ─────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('How Coins Work', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 12),
                    _ruleRow(Icons.delivery_dining_rounded, 'Earn', 'Get 1 coin for every ₹10 spent after delivery'),
                    const SizedBox(height: 8),
                    _ruleRow(Icons.savings_rounded, 'Redeem', '1 coin = ₹1 discount on your next order'),
                    const SizedBox(height: 8),
                    _ruleRow(Icons.refresh_rounded, 'Revert', 'Coins are deducted if you get a refund'),
                    const SizedBox(height: 8),
                    _ruleRow(Icons.check_circle_outline_rounded, 'Credit', 'Coins credited only after order is delivered'),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Transaction history ───────────────────────────
                const Text('Transaction History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 12),

                if (coins.wallet == null || coins.wallet!.transactions.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                    ),
                    child: Column(children: [
                      const Icon(Icons.stars_rounded, color: Color(AppColors.coins), size: 44),
                      const SizedBox(height: 12),
                      const Text('No transactions yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Place an order to start earning coins!',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500), textAlign: TextAlign.center),
                    ]),
                  )
                else
                  ...coins.wallet!.transactions.map((tx) => _TxTile(tx: tx,
                    typeLabel: _typeLabel(tx.type),
                    typeColor: _typeColor(tx.type),
                    typeIcon: _typeIcon(tx.type),
                    formattedDate: _formatDate(tx.createdAt),
                  )),

                const SizedBox(height: 32),
              ],
            ),
          ),
    );
  }

  Widget _ruleRow(IconData icon, String title, String desc) => Row(children: [
    Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        color: const Color(AppColors.coins).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: const Color(AppColors.coins)),
    ),
    const SizedBox(width: 10),
    Expanded(child: RichText(text: TextSpan(
      children: [
        TextSpan(text: '$title  ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(AppColors.textPrimary))),
        TextSpan(text: desc, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      ],
    ))),
  ]);
}

class _TxTile extends StatelessWidget {
  final CoinTransaction tx;
  final String typeLabel, formattedDate;
  final Color typeColor;
  final IconData typeIcon;
  const _TxTile({required this.tx, required this.typeLabel, required this.typeColor, required this.typeIcon, required this.formattedDate});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
    ),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(typeIcon, color: typeColor, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tx.description ?? typeLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        if (tx.orderNumber != null)
          Text('Order: ${tx.orderNumber}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        Text(formattedDate, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
      ])),
      Text(
        '${tx.type == 'earned' ? '+' : tx.type == 'redeemed' || tx.type == 'reverted' ? '-' : ''}${tx.coins}',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: typeColor),
      ),
    ]),
  );
}
