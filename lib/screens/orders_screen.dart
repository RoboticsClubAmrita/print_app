import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/pricing.dart';
import '../models/print_order.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/fx.dart';
import '../widgets/status_chip.dart';
import '../widgets/ticket_card.dart';
import 'order_detail_screen.dart';

/// The Orders tab, laid out like the website's Orders page
/// (print_integrated `src/user/pages/app/orders/OrdersPage.tsx`):
/// "Your prints" eyebrow, title + refresh, Active / History underline tabs
/// with counts, and a boarding-pass ticket per order.
///
/// (Until 2026-11-20 this tab rendered a stale copy of the Billing page.)
class OrdersTab extends StatefulWidget {
  final bool demoMode;
  final VoidCallback? onDemoComplete;

  const OrdersTab({super.key, this.demoMode = false, this.onDemoComplete});

  @override
  State<OrdersTab> createState() => OrdersTabState();
}

enum _OrdersView { active, history }

class OrdersTabState extends State<OrdersTab> {
  _OrdersView _view = _OrdersView.active;
  bool _refreshing = false;

  /// Two ticket columns from this width up, like the website's `sm:grid-cols-2`.
  static const _twoColumnWidth = 640.0;
  static const _gap = 14.0;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await context.read<AppState>().refreshOrders();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not refresh your orders. Check your connection.')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _open(PrintOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final active = state.activeOrders;
    final history = state.historyOrders;
    final shown = _view == _OrdersView.active ? active : history;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.black,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottomNavScrollClearance(context)),
          children: [
            FadeSlideIn(child: _header()),
            const SizedBox(height: 26),
            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: _tabs(active.length, history.length),
            ),
            const SizedBox(height: 22),
            if (shown.isEmpty)
              FadeSlideIn(
                key: ValueKey('empty-$_view'),
                delay: const Duration(milliseconds: 100),
                child: _emptyState(state),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= _twoColumnWidth ? 2 : 1;
                  final width = (constraints.maxWidth - _gap * (columns - 1)) / columns;
                  return Wrap(
                    key: ValueKey(_view),
                    spacing: _gap,
                    runSpacing: _gap,
                    children: [
                      for (var i = 0; i < shown.length; i++)
                        SizedBox(
                          width: width,
                          child: FadeSlideIn(
                            delay: Duration(milliseconds: 80 + 50 * i.clamp(0, 8)),
                            child: _OrderTicket(order: shown[i], onTap: () => _open(shown[i])),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'YOUR PRINTS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Orders',
                style: TextStyle(
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
        ),
        Pressable(
          onTap: _refreshing ? null : _refresh,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: _refreshing
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary),
                    )
                  : const Icon(Icons.refresh_rounded, size: 21, color: AppColors.textSecondary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabs(int activeCount, int historyCount) {
    Widget tab(_OrdersView view, String label, int count) {
      final selected = _view == view;
      return Pressable(
        onTap: () => setState(() => _view = view),
        child: Padding(
          padding: const EdgeInsets.only(right: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: AppMotion.fast,
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                      color: selected ? AppColors.black : AppColors.textSecondary,
                    ),
                    child: Text(label),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: AppColors.textSecondary.withValues(alpha: selected ? 1 : 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedContainer(
                duration: AppMotion.normal,
                curve: AppMotion.ease,
                height: 2,
                width: selected ? 52 : 0,
                decoration: BoxDecoration(
                  color: AppColors.black,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          tab(_OrdersView.active, 'Active', activeCount),
          tab(_OrdersView.history, 'History', historyCount),
        ],
      ),
    );
  }

  Widget _emptyState(AppState state) {
    final isActive = _view == _OrdersView.active;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: AppDecor.card(radius: 26),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(color: AppColors.chip, shape: BoxShape.circle),
            child: Icon(
              isActive ? Icons.inbox_outlined : Icons.inventory_2_outlined,
              size: 24,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isActive ? 'Nothing printing right now' : 'No collected orders yet',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          if (isActive) ...[
            const SizedBox(height: 6),
            const Text(
              'Start a print and track it here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => state.requestTab(0),
              child: const Text('Start a print'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Boarding-pass ticket for one order, matching the website's `OrderTicket`.
class _OrderTicket extends StatelessWidget {
  final PrintOrder order;
  final VoidCallback onTap;

  const _OrderTicket({required this.order, required this.onTap});

  static final _date = DateFormat('MMM d');

  bool get _isImage {
    final name = order.fileName.toLowerCase();
    return name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png');
  }

  @override
  Widget build(BuildContext context) {
    return TicketCard(
      notchColor: AppColors.bg,
      onTap: onTap,
      top: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              _isImage ? Icons.image_outlined : Icons.description_outlined,
              size: 20,
              color: AppColors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.id} • ${order.fileSizeKb} KB',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(status: order.status),
        ],
      ),
      bottom: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _MetaChip(_date.format(order.scheduledFor ?? order.createdAt)),
                  _MetaChip('${order.pages} pg × ${order.copies}'),
                  _MetaChip(order.side == PrintSide.single ? '1-side' : '2-side'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _Barcode(seed: order.id),
          const SizedBox(width: 12),
          Text(
            rupees(order.cost),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Deterministic mini barcode drawn from the order id, the same 18 bars the
/// website draws, so a ticket looks identical on both.
class _Barcode extends StatelessWidget {
  final String seed;

  const _Barcode({required this.seed});

  @override
  Widget build(BuildContext context) {
    final units = seed.isEmpty ? [0] : seed.codeUnits;
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 18; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Builder(builder: (_) {
              final code = units[i % units.length] + i * 7;
              return Container(
                width: code % 3 == 0 ? 3 : 1.5,
                decoration: BoxDecoration(
                  color: AppColors.black.withValues(alpha: code % 4 == 0 ? 0.25 : 0.75),
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
