import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../config/app_config.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_loader.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _editing = false;
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  late AnimationController _headerController;
  late Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _headerFade =
        CurvedAnimation(parent: _headerController, curve: Curves.easeOut);
    _headerController.forward();
    _populate();
  }

  void _populate() {
    final user = context.read<AuthProvider>().user;
    _nameCtrl.text = user?.name ?? '';
    _mobileCtrl.text = user?.mobile ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _headerController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    AppLoader.show(context, message: 'Saving...');
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile({
      'name': _nameCtrl.text.trim(),
      if (_mobileCtrl.text.trim().isNotEmpty) 'mobile': _mobileCtrl.text.trim(),
    });
    AppLoader.hide();
    if (!mounted) return;
    if (ok) {
      setState(() => _editing = false);
      AppToast.success(context, 'Profile updated successfully!');
    } else {
      AppToast.error(context, auth.error ?? 'Failed to update');
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                  color: const Color(AppColors.error).withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.logout_rounded,
                  color: Color(AppColors.error), size: 28),
            ),
            const SizedBox(height: 16),
            const Text('Log Out?',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 8),
            Text('You will be signed out of your account.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(
                  child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await context.read<AuthProvider>().logout();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppColors.error)),
                child: const Text('Log Out'),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) return const SizedBox();

    return Scaffold(
      backgroundColor: const Color(AppColors.background),
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
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
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: FadeTransition(
                    opacity: _headerFade,
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        GestureDetector(
                          onTap: () => setState(() {
                            if (_editing) _populate();
                            _editing = !_editing;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(
                                  _editing
                                      ? Icons.close_rounded
                                      : Icons.edit_rounded,
                                  color: Colors.white,
                                  size: 15),
                              const SizedBox(width: 6),
                              Text(_editing ? 'Cancel' : 'Edit Profile',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      // Avatar
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 16,
                                offset: const Offset(0, 6))
                          ],
                        ),
                        child: Center(
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Color(AppColors.primary),
                                fontSize: 38,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(user.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(user.email,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13)),
                      if (user.coinBalance > 0) ...[
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/coins'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.stars_rounded,
                                  color: Color(AppColors.coins), size: 20),
                              const SizedBox(width: 8),
                              Text('${user.coinBalance} Coins',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15)),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right_rounded,
                                  color: Colors.white70, size: 18),
                            ]),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
          ),
          // Body
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_editing) ...[
                    _sectionLabel('Personal Info'),
                    const SizedBox(height: 10),
                    _card([
                      _field(
                          'Full Name', _nameCtrl, Icons.person_outline_rounded,
                          hint: 'Full name'),
                      _divider(),
                      _field('Mobile Number', _mobileCtrl, Icons.phone_outlined,
                          hint: '9876543210', type: TextInputType.phone),
                    ]),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: auth.loading ? null : _save,
                      icon: auth.loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: PizzaSpinner(size: 20, color: Colors.white))
                          : const Icon(Icons.save_rounded, size: 18),
                      label: Text(auth.loading ? 'Saving...' : 'Save Changes',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52)),
                    ),
                  ] else ...[
                    _sectionLabel('Personal Info'),
                    const SizedBox(height: 10),
                    _infoCard([
                      _infoTile(Icons.email_outlined, 'Email', user.email),
                      if (user.mobile != null)
                        _infoTile(Icons.phone_outlined, 'Mobile',
                            '+91 ${user.mobile}'),
                    ]),
                    const SizedBox(height: 20),
                    _sectionLabel('My Account'),
                    const SizedBox(height: 10),
                    _menuCard([
                      _menuItem(Icons.receipt_long_rounded, 'My Orders',
                          () => Navigator.pushNamed(context, '/orders')),
                      _menuItem(Icons.stars_rounded, 'My Coins',
                          () => Navigator.pushNamed(context, '/coins'),
                          trailing: user.coinBalance > 0
                              ? _coinBadge(user.coinBalance)
                              : null),
                      _menuItem(Icons.local_offer_rounded, 'Coupons',
                          () => Navigator.pushNamed(context, '/coupons')),
                      _menuItem(Icons.headset_mic_rounded, 'Support',
                          () => Navigator.pushNamed(context, '/support')),
                      _menuItem(Icons.assignment_return_rounded, 'My Refunds',
                          () => Navigator.pushNamed(context, '/refunds')),
                      _menuItem(Icons.notifications_outlined, 'Notifications',
                          () => Navigator.pushNamed(context, '/notifications')),
                    ]),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout_rounded,
                            color: Color(AppColors.error), size: 18),
                        label: const Text('Log Out',
                            style: TextStyle(
                                color: Color(AppColors.error),
                                fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(AppColors.error)),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Center(
                    child: Text('Developed by GOBT',
                        style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Color(AppColors.textSecondary),
          letterSpacing: 0.5));

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
          ],
        ),
        child: Column(children: children),
      );

  Widget _divider() =>
      Divider(height: 1, color: Colors.grey.shade100, indent: 52);

  Widget _field(String label, TextEditingController ctrl, IconData icon,
          {String? hint, TextInputType? type}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          Icon(icon, size: 20, color: const Color(AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(
              child: TextField(
            controller: ctrl,
            keyboardType: type,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          )),
        ]),
      );

  Widget _infoCard(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
          ],
        ),
        child: Column(children: children),
      );

  Widget _infoTile(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: const Color(AppColors.primary).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: const Color(AppColors.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ])),
        ]),
      );

  Widget _menuCard(List<Widget> items) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
          ],
        ),
        child: Column(children: items),
      );

  Widget _menuItem(IconData icon, String label, VoidCallback onTap,
          {Widget? trailing}) =>
      InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: const Color(AppColors.primary).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10)),
              child:
                  Icon(icon, size: 18, color: const Color(AppColors.primary)),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14))),
            if (trailing != null) ...[trailing, const SizedBox(width: 6)],
            Icon(Icons.chevron_right_rounded,
                size: 20, color: Colors.grey.shade300),
          ]),
        ),
      );

  Widget _coinBadge(int count) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(AppColors.coins).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('$count',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Color(AppColors.coins))),
      );
}
