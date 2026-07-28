import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/pricing.dart';
import '../models/print_order.dart';
import '../services/api_client.dart';
import '../services/razorpay_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/fx.dart';
import '../widgets/status_chip.dart';
import '../widgets/ticket_card.dart';
import 'otp_verification_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _busy = false;

  Future<void> _payNow(PrintOrder order) async {
    if (_busy) return;
    setState(() => _busy = true);
    final state = context.read<AppState>();
    try {
      final created = await ApiClient.createPaymentOrder(order.jobId);
      final result = await RazorpayService.checkout(
        keyId: created['keyId'].toString(),
        orderId: created['orderId'].toString(),
        amountInPaise: (created['amountInPaise'] as num).toInt(),
        name: state.user?.name ?? 'PrintEase User',
        description: 'Print job ${order.id}',
        userEmail: state.user?.email,
        userPhone: state.user?.phone,
      );
      await ApiClient.verifyPayment(
        razorpayOrderId: result.orderId,
        razorpayPaymentId: result.paymentId,
        razorpaySignature: result.signature,
      );
      await state.refreshOrders();
      if (!mounted) return;
      await showSuccessOverlay(
        context,
        title: 'Payment Successful',
        subtitle: '${rupees(order.cost)} paid for ${order.fileName}.',
        icon: Icons.account_balance_wallet_rounded,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Payment failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(PrintOrder order) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<AppState>().cancelOrder(order);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestAndConfirmCollection(PrintOrder order) async {
    if (_busy) return;
    final state = context.read<AppState>();

    // Enforce outstanding dues before any collection OTP is generated.
    if (state.outstandingDues > 0) {
      await _showPendingDuesPopup(state);
      return;
    }

    setState(() => _busy = true);
    final String email;
    try {
      email = await state.requestCollection(order);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    // The OTP screen owns verification and its own success animation; the
    // stack refresh happens inside confirmCollection.
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          title: 'Confirm collection',
          subtitle: 'Enter the 4-digit code sent to '
              '${email.isEmpty ? 'your email' : email}.',
          verifyLabel: 'Confirm collection',
          successTitle: 'Collection Confirmed',
          successSubtitle: 'Enjoy your prints!',
          successIcon: Icons.inventory_2_rounded,
          headerIcon: Icons.local_shipping_outlined,
          onVerify: (code) async {
            try {
              await state.confirmCollection(order, code);
              return null;
            } on ApiException catch (e) {
              return e.message;
            }
          },
          onResend: () async {
            try {
              await state.requestCollection(order);
              return null;
            } on ApiException catch (e) {
              return e.message;
            }
          },
        ),
      ),
    );
  }

  /// Premium blocker shown when the user still owes money: no OTP is generated
  /// and the only action is to head to Billing. Dismissible only by tapping
  /// outside (no close button, no timeout).
  Future<void> _showPendingDuesPopup(AppState state) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _PendingDuesDialog(
        amount: state.outstandingDues,
        onGoToBilling: () {
          Navigator.of(dialogContext).pop();
          Navigator.of(context).popUntil((route) => route.isFirst);
          state.requestTab(2);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final order = state.orders.firstWhere((o) => o.id == widget.orderId);

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

  static const _timelineSteps = [
    OrderStatus.pending,
    OrderStatus.queued,
    OrderStatus.printing,
    OrderStatus.ready,
    OrderStatus.collected,
  ];

  Widget _timelineCard(PrintOrder order) {
    if (order.status == OrderStatus.cancelled || order.status == OrderStatus.failed) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Text(
              order.status == OrderStatus.cancelled
                  ? 'This order was cancelled.'
                  : 'This order failed to print.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }
    final steps = _timelineSteps;
    // awaitingStack (printed, no free stack yet) sits at the same node as
    // ready (printed and sitting in a stack) — both mean "printing is done".
    // scheduled (paid, holding until its print time) sits at the same node
    // as pending — both are "before the print queue".
    final displayStatus = switch (order.status) {
      OrderStatus.awaitingStack => OrderStatus.ready,
      OrderStatus.scheduled => OrderStatus.pending,
      _ => order.status,
    };
    final currentIndex = steps.indexOf(displayStatus);
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
              // While awaiting a free stack, show that nuance on the node
              // that would otherwise just say "Ready to Collect".
              i == currentIndex && order.status == OrderStatus.awaitingStack
                  ? order.status.label
                  : steps[i].label,
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
          _costRow('Paper', '${order.pageType} • ${order.colorModeLabel}'),
          _costRow('Side', order.side.label),
          _costRow('Pages per copy', '${order.pages}'),
          _costRow('Copies', '${order.copies}'),
          if (order.costPerPage > 0) ...[
            _costRow('Rate charged', '₹${order.costPerPage} / page'),
            _costRow('Print cost', rupees(order.basePrintCost.round())),
          ] else
            _costRow('Rate', rateLabel(order.side)),
          if (order.balanceApplied > 0) ...[
            _costRow(
              'Outstanding balance added',
              rupees(order.balanceApplied.round()),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                'Carried over from uncollected prints left in a stack past '
                'the free window — paying this invoice clears it.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
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
      case OrderStatus.pending:
        return FilledButton.icon(
          icon: const Icon(Icons.payment_rounded, size: 20),
          label: Text(_busy ? 'Processing…' : 'Pay ${rupees(order.cost)}'),
          onPressed: _busy ? null : () => _payNow(order),
        );
      case OrderStatus.scheduled:
        return Column(
          children: [
            if (order.scheduledFor != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Scheduled for ${DateFormat('MMM d, h:mm a').format(order.scheduledFor!)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.cancel_outlined, size: 20),
              label: Text(_busy ? 'Cancelling…' : 'Cancel Order'),
              onPressed: _busy ? null : () => _cancel(order),
            ),
          ],
        );
      case OrderStatus.ready:
        return Column(
          children: [
            if (order.stackName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Collect from Stack ${order.stackName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            FilledButton.icon(
              icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: Text(_busy ? 'Processing…' : 'Request Collection'),
              onPressed: _busy ? null : () => _requestAndConfirmCollection(order),
            ),
          ],
        );
      case OrderStatus.awaitingStack:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Your document is printed and waiting for a free pickup slot. '
            "We'll notify you the moment it's ready to collect.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        );
      case OrderStatus.queued:
        return OutlinedButton.icon(
          icon: const Icon(Icons.cancel_outlined, size: 20),
          label: Text(_busy ? 'Cancelling…' : 'Cancel Order'),
          onPressed: _busy ? null : () => _cancel(order),
        );
      case OrderStatus.printing:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Your document is printing now.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        );
      case OrderStatus.collected:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 22),
              const SizedBox(width: 10),
              Text(
                order.collectedStackName != null
                    ? 'Collected from Stack ${order.collectedStackName} — thank you!'
                    : 'Collected — thank you!',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        );
      case OrderStatus.cancelled:
      case OrderStatus.failed:
        return const SizedBox.shrink();
    }
  }
}

/// The pending-dues blocker card. Only "Go to Billing" acts; tapping the
/// dimmed backdrop dismisses it.
class _PendingDuesDialog extends StatelessWidget {
  final num amount;
  final VoidCallback onGoToBilling;

  const _PendingDuesDialog({required this.amount, required this.onGoToBilling});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
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
                color: AppColors.warning.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: AppColors.warning, size: 32),
            ),
            const SizedBox(height: 18),
            const Text(
              'Pending Dues',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'You have pending dues. Please complete the payment before '
              'collecting your printed materials.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            if (amount > 0) ...[
              const SizedBox(height: 10),
              Text(
                'Outstanding: ${rupees(amount.round())}',
                style:
                    const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onGoToBilling,
                icon: const Icon(Icons.account_balance_wallet_outlined,
                    size: 20),
                label: const Text('Go to Billing'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap outside to dismiss',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}