import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/pricing.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/dot_grid.dart';
import '../widgets/fx.dart';
import 'billing_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'orders_screen.dart';

/// Hosts the four tabs behind the floating black pill navigation.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _tabAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );
  late final CurvedAnimation _tabCurve = CurvedAnimation(
    parent: _tabAnim,
    curve: Curves.easeOutQuart,
  );
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Poll for order status changes so print-ready/collected notifications
    // fire while the app is open, without the user manually refreshing.
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      context.read<AppState>().refreshOrders();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabCurve.dispose();
    _tabAnim.dispose();
    super.dispose();
  }

  void _selectTab(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _tabAnim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: _index == 1 ? AppColors.black : AppColors.bg,
      body: FadeTransition(
        opacity: _tabCurve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.012),
            end: Offset.zero,
          ).animate(_tabCurve),
          child: ResponsiveFrame(
            child: IndexedStack(
              index: _index,
              children: [
                HomeTab(
                  onViewOrders: () => _selectTab(1),
                  onViewProfile: () => _selectTab(3),
                ),
                const OrdersTab(),
                const BillingTab(),
                const _ProfileTab(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
        child: SafeArea(
          child: FloatingBottomNav(index: _index, onTap: _selectTab),
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
        children: [
          const FadeSlideIn(
            child: Text(
              'Profile',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ),
          const SizedBox(height: 18),
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: _identityCard(user?.initials ?? '?', user?.name ?? 'Guest',
                user?.email ?? ''),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 130),
            child: Row(
              children: [
                _statCard(
                    Icons.print_rounded, 'Orders', '${state.orders.length}'),
                const SizedBox(width: 12),
                _statCard(Icons.inventory_2_outlined, 'Collected',
                    '${state.historyOrders.length}'),
                const SizedBox(width: 12),
                _statCard(Icons.account_balance_wallet_outlined, 'Spent',
                    rupees(state.totalSpent)),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const FadeSlideIn(
            delay: Duration(milliseconds: 200),
            child: Text(
              'Account',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            delay: const Duration(milliseconds: 240),
            child: Container(
              decoration: AppDecor.card(),
              child: Column(
                children: [
                  _menuRow(
                    context,
                    icon: Icons.sell_outlined,
                    title: 'Print Rates',
                    subtitle: 'Per-page and per-sheet pricing',
                    onTap: () => _showRatesSheet(context),
                  ),
                  const Divider(height: 1, indent: 66, color: AppColors.border),
                  _menuRow(
                    context,
                    icon: Icons.info_outline_rounded,
                    title: 'About PrintEase',
                    subtitle: 'Campus printing, minus the queue',
                    onTap: () => _showAboutSheet(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          FadeSlideIn(
            delay: const Duration(milliseconds: 300),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Log Out'),
              onPressed: () {
                context.read<AppState>().logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _identityCard(String initials, String name, String email) {
    return Container(
      decoration: AppDecor.darkPanel(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DotGrid(color: Colors.white10, spacing: 24, radius: 1.2),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.white,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: AppColors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                          child: const Text(
                            '⚡ PrintEase Member',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: AppDecor.card(radius: 22),
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.chip,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 17, color: AppColors.black),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.chip,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19, color: AppColors.black),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRatesSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _RatesSheetContent(),
    );
  }

  void _showAboutSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppDecor.darkPanelGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.print_rounded,
                    color: AppColors.white, size: 28),
              ),
              const SizedBox(height: 14),
              const Text(
                'PrintEase',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Upload documents, customize print settings and collect '
                'your prints — without the queue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Content of the "Print Rates" bottom sheet.
///
/// Loads pricing exactly once via a `late final` future captured in
/// [initState]. Passing `state.loadPricing()` straight into a
/// `FutureBuilder`'s `future:` from inside `build()` — as this used to do —
/// creates a brand-new [Future] (and kicks off a new network call) on every
/// rebuild, which resets the FutureBuilder to its loading spinner each time.
/// Since [AppState] notifies listeners roughly every 20s (order polling)
/// and drag/scroll gestures on a modal sheet can also trigger rebuilds, the
/// whole sheet appeared to "keep refreshing" instead of showing the rates.
class _RatesSheetContent extends StatefulWidget {
  const _RatesSheetContent();

  @override
  State<_RatesSheetContent> createState() => _RatesSheetContentState();
}

class _RatesSheetContentState extends State<_RatesSheetContent> {
  late final Future<void> _future = context.read<AppState>().loadPricing();

  String _rateLabel(Map<String, dynamic> price) {
    final size = (price['size'] ?? '').toString();
    final type = price['type'] == 'colour' ? 'Colour' : 'B&W';
    final side = price['side'] == 'double' ? 'Double-sided' : 'Single-sided';
    return '$size • $type • $side';
  }

  Widget _rateRow(IconData icon, String label, String rate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.black),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style:
                  const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            rate,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Print Rates',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            FutureBuilder<void>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return Consumer<AppState>(
                  builder: (context, state, _) {
                    if (state.pricing.isEmpty) {
                      return const Text(
                        'No print rates configured yet.',
                        style: TextStyle(color: AppColors.textSecondary),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < state.pricing.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _rateRow(
                            (state.pricing[i]['side'] == 'double')
                                ? Icons.flip_to_back_rounded
                                : Icons.description_outlined,
                            _rateLabel(state.pricing[i]),
                            '₹${state.pricing[i]['price']} / '
                            '${state.pricing[i]['side'] == 'double' ? 'sheet' : 'page'}',
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Double-sided fits two pages per sheet — cheaper for long '
              'documents and better for the planet.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
