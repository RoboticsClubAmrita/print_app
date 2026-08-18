import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/pricing.dart';
import '../models/print_order.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/dot_grid.dart';
import '../widgets/fx.dart';

/// Billing tab: dark statement card with an oversized total-due numeral,
/// order-wise cost breakdown and payment history.
class BillingTab extends StatefulWidget {
  final bool demoMode;
  final VoidCallback? onDemoComplete;
  const BillingTab({super.key, this.demoMode = false, this.onDemoComplete});

  @override
  State<BillingTab> createState() => BillingTabState();
}

class BillingTabState extends State<BillingTab> {
  bool _paying = false;
  bool _payingDues = false;
  bool _breakdownExpanded = false;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().loadPenalties();
  }

  Future<void> _payDues(AppState state) async {
    if (_payingDues) return;
    setState(() => _payingDues = true);
    try {
      final paidAmount = await state.payOutstandingDues();
      if (!mounted) return;
      await showSuccessOverlay(
        context,
        title: 'Dues Cleared',
        subtitle: '${rupees(paidAmount.round())} paid — you are all set.',
        icon: Icons.account_balance_wallet_rounded,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Payment failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _payingDues = false);
    }
  }

  Future<void> _payAllDue(AppState state) async {
    if (_paying) return;
    setState(() => _paying = true);

    if (widget.demoMode) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      state.markDemoOrderPaid();
      await showSuccessOverlay(
        context,
        title: 'Payment Successful',
        subtitle: 'Demo payment complete — you are all set.',
        icon: Icons.account_balance_wallet_rounded,
      );
      if (mounted) setState(() => _paying = false);
      widget.onDemoComplete?.call();
      return;
    }

    try {
      final unpaid = List<PrintOrder>.from(state.unpaidOrders);
      var cleared = 0;
      final undelivered = <String>[];
      for (final order in unpaid) {
        // Pays and then sends the document each order has been holding on this
        // device since it was placed — see AppState.payForOrder.
        final problem = await state.payForOrder(order);
        if (problem != null) undelivered.add('${order.fileName}: $problem');
        cleared += order.cost;
      }
      if (!mounted) return;
      await showSuccessOverlay(
        context,
        title: 'Payment Successful',
        subtitle: '${rupees(cleared)} cleared — you are all set.',
        icon: Icons.account_balance_wallet_rounded,
      );
      if (undelivered.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Still sending: ${undelivered.join('; ')}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Payment failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final unpaid = state.unpaidOrders;
    final paid = state.paidOrders;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
        children: [
          const FadeSlideIn(
            child: Text(
              'Billing',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const FadeSlideIn(
            delay: Duration(milliseconds: 40),
            child: Text(
              'Order-wise costs and dues',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
          FadeSlideIn(
            delay: const Duration(milliseconds: 90),
            child: _statementCard(context, state, unpaid.length),
          ),
          if (state.outstandingDues > 0) ...[
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: _duesCard(state),
            ),
          ],
          if (unpaid.isNotEmpty) ...[
            const SizedBox(height: 26),
            FadeSlideIn(
              delay: const Duration(milliseconds: 160),
              child: Pressable(
                onTap: () => setState(() => _breakdownExpanded = !_breakdownExpanded),
                child: Row(
                  children: [
                    const Text(
                      'Cost Breakdown',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _breakdownExpanded ? 0.5 : 0,
                      duration: AppMotion.fast,
                      curve: AppMotion.ease,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 24,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${unpaid.length} order${unpaid.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    for (var i = 0; i < unpaid.length; i++) ...[
                      _breakdownCard(unpaid[i]),
                      if (i < unpaid.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              crossFadeState: _breakdownExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: AppMotion.normal,
              sizeCurve: AppMotion.ease,
            ),
          ],
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (paid.isEmpty)
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 280),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: AppDecor.card(radius: 22),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'No payments yet.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < paid.length; i++) ...[
                    FadeSlideIn(
                      delay: Duration(milliseconds: 280 + 40 * (i < 6 ? i : 6)),
                      child: _historyRow(paid[i]),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statementCard(BuildContext context, AppState state, int unpaidCount) {
    return Container(
      decoration: AppDecor.darkPanel(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DotGrid(color: Colors.white10, spacing: 24, radius: 1.2),
            ),
            Positioned(
              right: -28,
              bottom: -30,
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 150,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL DUE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedCount(
                    value: state.totalDue,
                    format: rupees,
                    style: const TextStyle(
                      fontSize: 56,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                      letterSpacing: -1,
                      fontFamily: kFontFamily,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unpaidCount == 0
                        ? 'No pending payments — all clear ✨'
                        : 'across $unpaidCount unpaid '
                            'order${unpaidCount > 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.black,
                      disabledBackgroundColor:
                          Colors.white.withValues(alpha: 0.16),
                      disabledForegroundColor: Colors.white38,
                    ),
                    onPressed: state.totalDue == 0 || _paying
                        ? null
                        : () => _payAllDue(state),
                    child: _paying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Pay Now'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _duesCard(AppState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 20, color: AppColors.warning),
              const SizedBox(width: 8),
              const Text(
                'Outstanding Dues',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                rupees(state.outstandingDues.round()),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Storage fees from uncollected prints left in a stack past the '
            'free window.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
          if (state.penalties.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final p in state.penalties)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        (p['referenceId'] ?? 'Print job').toString(),
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                      ),
                    ),
                    Text(
                      rupees((((p['amount'] as num?) ?? 0) - ((p['settledAmount'] as num?) ?? 0)).round()),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _payingDues ? null : () => _payDues(state),
            child: _payingDues
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                  )
                : const Text('Pay Dues'),
          ),
        ],
      ),
    );
  }

  Widget _breakdownCard(PrintOrder o) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppDecor.card(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.chip,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.description_outlined, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${o.pages} pages × ${o.copies} '
                  '${o.copies > 1 ? 'copies' : 'copy'} • ${o.side.label}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  o.costPerPage > 0
                      ? 'at ₹${o.costPerPage} / page'
                      : rateLabel(o.side),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (o.balanceApplied > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '+ ${rupees(o.balanceApplied.round())} carried-over balance',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            rupees(o.cost),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _historyRow(PrintOrder o) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: AppDecor.card(radius: 22),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 18,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  DateFormat('MMM d, yyyy').format(o.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            rupees(o.cost),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}