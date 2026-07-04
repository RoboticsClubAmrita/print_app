import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/pricing.dart';
import '../models/print_order.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/dot_grid.dart';
import '../widgets/fx.dart';

/// Billing tab: dark statement card with an oversized total-due numeral,
/// order-wise cost breakdown and payment history.
class BillingTab extends StatelessWidget {
  const BillingTab({super.key});

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
          if (unpaid.isNotEmpty) ...[
            const SizedBox(height: 26),
            const FadeSlideIn(
              delay: Duration(milliseconds: 160),
              child: Text(
                'Cost Breakdown',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < unpaid.length; i++) ...[
              FadeSlideIn(
                delay: Duration(milliseconds: 200 + 50 * (i < 5 ? i : 5)),
                child: _breakdownCard(unpaid[i]),
              ),
              const SizedBox(height: 12),
            ],
          ],
          const SizedBox(height: 14),
          const FadeSlideIn(
            delay: Duration(milliseconds: 240),
            child: Text(
              'Payment History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
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
                    onPressed: state.totalDue == 0
                        ? null
                        : () {
                            final cleared = rupees(state.totalDue);
                            context.read<AppState>().payAllDue();
                            showSuccessOverlay(
                              context,
                              title: 'Payment Successful',
                              subtitle: '$cleared cleared — you are all set.',
                              icon: Icons.account_balance_wallet_rounded,
                            );
                          },
                    child: const Text('Pay Now'),
                  ),
                ],
              ),
            ),
          ],
        ),
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
                  '${o.sheetsPerCopy * o.copies} sheets at ${rateLabel(o.side)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
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
