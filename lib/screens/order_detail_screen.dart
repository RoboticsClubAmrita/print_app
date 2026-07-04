import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/pricing.dart';
import '../models/print_order.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/fx.dart';
import '../widgets/status_chip.dart';
import '../widgets/ticket_card.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final order = state.orders.firstWhere((o) => o.id == orderId);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Pressable(
                    pressedScale: 0.92,
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_rounded, size: 22),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Order Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  FadeSlideIn(child: _summaryTicket(order)),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 70),
                    child: _timelineCard(order),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 140),
                    child: _costCard(order),
                  ),
                  const SizedBox(height: 20),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 210),
                    child: _actions(context, order),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryTicket(PrintOrder order) {
    return TicketCard(
      notchColor: AppColors.bg,
      top: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.chip,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.description_outlined, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${order.id} • ${order.fileSizeKb} KB',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(status: order.status),
        ],
      ),
      bottom: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _settingChip(order.side.label),
          _settingChip('${order.pages} pages'),
          _settingChip(
              '${order.copies} ${order.copies > 1 ? 'copies' : 'copy'}'),
          _settingChip(
            order.scheduledNow
                ? 'Printed now'
                : DateFormat('MMM d, h:mm a').format(order.scheduledAt),
          ),
        ],
      ),
    );
  }

  Widget _settingChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _timelineCard(PrintOrder order) {
    const steps = OrderStatus.values;
    final currentIndex = steps.indexOf(order.status);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Status',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < steps.length; i++)
            _timelineStep(
              steps[i].label,
              reached: i <= currentIndex,
              isCurrent: i == currentIndex,
              isLast: i == steps.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _timelineStep(
    String label, {
    required bool reached,
    required bool isCurrent,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutQuart,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: reached ? AppColors.black : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: reached ? AppColors.black : AppColors.border,
                    width: 2,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: AppColors.black.withValues(alpha: 0.25),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: reached
                    ? const Icon(Icons.check, size: 13, color: AppColors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutQuart,
                    width: 2,
                    color: reached ? AppColors.black : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Padding(
            padding: EdgeInsets.only(top: 1, bottom: isLast ? 0 : 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    color: reached ? AppColors.black : AppColors.textSecondary,
                  ),
                ),
                if (isCurrent)
                  const Text(
                    'Current status',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _costCard(PrintOrder order) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Cost Breakdown',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.chip,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color:
                            order.paid ? AppColors.success : AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      order.paid ? 'Paid' : 'Payment due',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _costRow('Pages per copy', '${order.pages}'),
          _costRow('Copies', '${order.copies}'),
          _costRow(
            'Sheets used',
            '${order.sheetsPerCopy} × ${order.copies} = ${order.sheetsPerCopy * order.copies}',
          ),
          _costRow('Rate', rateLabel(order.side)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: AppColors.border),
          ),
          Row(
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                rupees(order.cost),
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _costRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, PrintOrder order) {
    switch (order.status) {
      case OrderStatus.ready:
        return FilledButton.icon(
          icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
          label: const Text('Confirm Collection'),
          onPressed: () {
            context.read<AppState>().confirmCollection(order);
            showSuccessOverlay(
              context,
              title: 'Collection Confirmed',
              subtitle: 'Enjoy your prints!',
              icon: Icons.inventory_2_rounded,
            );
          },
        );
      case OrderStatus.queued:
      case OrderStatus.printing:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.fast_forward_rounded, size: 20),
              label: const Text('Advance Status (demo)'),
              onPressed: () => context.read<AppState>().advanceStatus(order),
            ),
            const SizedBox(height: 8),
            const Text(
              'Demo app — advance the order manually since there is no real print shop backend.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ],
        );
      case OrderStatus.collected:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 22),
              SizedBox(width: 10),
              Text(
                'Collected — thank you!',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        );
    }
  }
}
