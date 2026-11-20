import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/session_store.dart';
import '../services/job_event_stream.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/dot_grid.dart';
import '../widgets/fx.dart';
import '../widgets/coach_tour.dart';
import 'billing_screen.dart';
import 'edit_profile_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'orders_screen.dart';
import '../data/pricing.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _index = 0;
  bool _demoMode = false;
  final _homeKey = GlobalKey<HomeTabState>();
  final _tourBottomNav = GlobalKey();
  final _ordersKey = GlobalKey<OrdersTabState>();
  final _billingKey = GlobalKey<BillingTabState>();
  final _profileKey = GlobalKey<ProfileTabState>();

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
  late final AppState _appState;

  /// Pushes job changes the moment they commit, so "printing" / "ready"
  /// notifications fire immediately instead of on the next 20 s poll.
  late final JobEventStream _jobEvents = JobEventStream(onChange: _pollOrders);

  @override
  void initState() {
    super.initState();
    _appState = context.read<AppState>();
    _appState.addListener(_onStateChange);
    _appState.tabRequest.addListener(_onTabRequest);
    WidgetsBinding.instance.addObserver(this);
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollOrders());
    _jobEvents.start();

    TourCoordinator.onReplay = _replayTour;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final userId = _appState.user?.id;
      final seen = await SessionStore.seenTour('tour', userId: userId);
      if (seen || !mounted) return;
      // Mark it the moment the tour is *shown*, not when it completes.
      // Marking on completion meant backgrounding the app, killing it, or
      // dismissing the walkthrough mid-way left the flag unset, so the tour
      // ran again at every launch.
      await SessionStore.markTourSeen('tour', userId: userId);
      if (!mounted) return;
      _startFullTour();
    });
  }

  /// Replay on demand (Profile -> About PrintEase). The coach marks live on
  /// the Home tab, so switch there first and wait for it to mount before the
  /// walkthrough tries to measure its targets.
  void _replayTour() {
    _selectTab(0);
    _startTourWhenHomeReady();
  }

  void _startTourWhenHomeReady([int attempt = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_homeKey.currentState == null) {
        if (attempt < _tourStartAttempts) _startTourWhenHomeReady(attempt + 1);
        return;
      }
      _startFullTour();
    });
  }

  /// Frames to wait for the Home tab before giving up on a replay.
  static const _tourStartAttempts = 10;

  bool _tourRunning = false;

  /// Runs the website's walkthrough (same steps, same copy, same order).
  /// Done → welcome dialog; ✕ / back → just closes, like the website.
  Future<void> _startFullTour() async {
    final home = _homeKey.currentState;
    if (home == null || _tourRunning) return;

    final targets = {...home.tourTargets, 'tour-nav': _tourBottomNav};
    final steps = [
      for (final id in tourOrder)
        if (targets[id] != null)
          TourStep(
            target: targets[id]!,
            title: tourCopy[id]!.$1,
            description: tourCopy[id]!.$2,
          ),
    ];

    _tourRunning = true;
    final result = await CoachTour.show(context, steps);
    _tourRunning = false;
    if (result == TourResult.finished) _showWelcomeDialog();
  }

  Future<void> _showWelcomeDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _WelcomeDialog(
        onOkPressed: () => Navigator.of(dialogContext).pop(),
        onDemoPressed: () {
          Navigator.of(dialogContext).pop();
          _startOrderDemo();
        },
      ),
    );
  }

  void _onStateChange() {
    if (!_appState.isLoggedIn && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please log in again.')),
      );
    }
  }

  void _onTabRequest() {
    final target = _appState.tabRequest.value;
    if (target != null && mounted) {
      _selectTab(target);
      _appState.tabRequest.value = null;
    }
  }

  /// Safety-net poll, matching the web app's (`useLiveOrders`). The live feed
  /// ([JobEventStream]) is what makes updates instant.
  static const _pollInterval = Duration(seconds: 20);

  /// Statuses change on the print side, not from anything this app does.
  /// A failed poll is harmless (the next one retries) but must not surface
  /// as an unhandled async error.
  void _pollOrders() {
    _appState.refreshOrders().catchError((Object e) {
      debugPrint('Order poll failed: $e');
    });
  }

  /// Timers do not fire while the app is backgrounded, so a user returning
  /// to check on a print would otherwise wait up to a full interval.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pollOrders();
      _jobEvents.start();
    } else if (state == AppLifecycleState.paused) {
      // No open sockets while backgrounded; resume refetches and reconnects.
      _jobEvents.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appState.removeListener(_onStateChange);
    _appState.tabRequest.removeListener(_onTabRequest);
    _pollTimer?.cancel();
    _jobEvents.stop();
    _tabCurve.dispose();
    _tabAnim.dispose();
    if (TourCoordinator.onReplay == _replayTour) {
      TourCoordinator.onReplay = null;
    }
    super.dispose();
  }

  void _selectTab(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _tabAnim.forward(from: 0);
  }

  void _startOrderDemo() {
    _appState.setDemoStage(DemoStage.pickDocument);
    setState(() => _demoMode = true);
    _selectTab(0);
  }

  void _endOrderDemo() {
    _appState.removeDemoOrder();
    setState(() => _demoMode = false);
    _selectTab(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.bg,
      // The demo bar is part of the layout, not an overlay floating on top of
      // it — the same shape the web app uses. Sitting in the column means it
      // pushes the page down instead of covering its header.
      body: Column(
        children: [
          if (_demoMode) _DemoBar(onExit: _endOrderDemo),
          Expanded(
            child: FadeTransition(
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
                        key: _homeKey,
                        onViewOrders: () => _selectTab(1),
                        onViewProfile: () => _selectTab(3),
                        bottomNavKey: _tourBottomNav,
                        demoMode: _demoMode,
                      ),
                      OrdersTab(
                        key: _ordersKey,
                        demoMode: _demoMode,
                        onDemoComplete: _endOrderDemo,
                      ),
                      BillingTab(
                        key: _billingKey,
                        demoMode: _demoMode,
                        onDemoComplete: _endOrderDemo,
                      ),
                      ProfileTab(key: _profileKey),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
        child: SafeArea(
          child: KeyedSubtree(
            key: _tourBottomNav,
            child: FloatingBottomNav(index: _index, onTap: _selectTab),
          ),
        ),
      ),
    );
  }
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => ProfileTabState();
}

class ProfileTabState extends State<ProfileTab> {
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
            child: _identityCard(
              user?.initials ?? '?',
              user?.name ?? 'Guest',
              user?.email ?? '',
            ),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 130),
            child: Row(
              children: [
                _statCard(Icons.print_rounded, 'Orders', '${state.orders.length}'),
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
          FadeSlideIn(
            delay: const Duration(milliseconds: 200),
            child: const Text(
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
                    icon: Icons.person_outline_rounded,
                    title: 'Edit Profile',
                    subtitle: 'Update your name, email and phone',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 66, color: AppColors.border),
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
              // Red text/icon on the neutral outline, like the website.
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                overlayColor: AppColors.danger,
              ),
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
                            horizontal: 10,
                            vertical: 5,
                          ),
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
      isScrollControlled: true,
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
      builder: (sheetContext) => SafeArea(
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
                'Upload documents, customize print settings and collect your prints — without the queue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
                  label: const Text('Replay walkthrough'),
                  onPressed: () {
                    // Close the sheet first: the tour highlights widgets
                    // behind it, and the shell owns the walkthrough.
                    Navigator.of(sheetContext).pop();
                    TourCoordinator.onReplay?.call();
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Runs the guided tour again from the first step.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
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
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
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
              Flexible(
                child: SingleChildScrollView(
                  child: FutureBuilder<void>(
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
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Double-sided fits two pages per sheet — cheaper for long documents and better for the planet.',
                style: TextStyle(
                  fontSize: 12.5,
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
class _WelcomeDialog extends StatelessWidget {
  final VoidCallback onOkPressed;
  final VoidCallback onDemoPressed;

  const _WelcomeDialog({required this.onOkPressed, required this.onDemoPressed});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      // Without a ceiling this stretched the full width of a desktop window,
      // which read as a banner rather than a dialog. Matches the ceiling the
      // rest of the app is laid out against (see ResponsiveFrame).
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kDialogMaxWidth),
        child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppDecor.darkPanelGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.celebration_rounded,
                color: AppColors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "You're All Set!",
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Welcome to PrintEase — you now know your way around. Go ahead and place your first print order!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onOkPressed,
                child: const Text('OK'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onDemoPressed,
              child: const Text('Show Me How to Order'),
            ),
          ],
        ),
        ),
      ),
    );
  }
}


/// Demo rail: the demo's own header, in the same dark-panel language as the
/// nav dock. Sits in normal layout flow rather than floating over the page, so
/// it can never cover the content it is describing.
///
/// Carries a stage label, a step count and a segmented progress track, so the
/// user can see where they are and how much is left — the demo previously gave
/// no sense of position at all.
class _DemoBar extends StatelessWidget {
  const _DemoBar({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final stage = context.select<AppState, DemoStage>((s) => s.demoStage);

    return Material(
      color: AppColors.black,
      child: Ink(
        decoration: const BoxDecoration(gradient: AppDecor.darkPanelGradient),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Text(
                        'DEMO',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: AppMotion.fast,
                        child: Text(
                          stage.label,
                          key: ValueKey(stage),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${stage.step}/${DemoStage.total}',
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.55),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: onExit,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Exit',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    children: [
                      for (var i = 1; i <= DemoStage.total; i++) ...[
                        if (i > 1) const SizedBox(width: 5),
                        Expanded(
                          child: AnimatedContainer(
                            duration: AppMotion.normal,
                            curve: Curves.easeOutCubic,
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(
                                alpha: i <= stage.step ? 0.95 : 0.18,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
