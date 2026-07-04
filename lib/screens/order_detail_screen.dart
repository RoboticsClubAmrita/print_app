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
    setState(() => _busy = true);
    final state = context.read<AppState>();
    try {
      final email = await state.requestCollection(order);
      if (!mounted) return;
      final otp = await _promptForOtp(email);
      if (otp == null || !mounted) return;
      await state.confirmCollection(order, otp);
      if (!mounted) return;
      await showSuccessOverlay(
        context,
        title: 'Collection Confirmed',
        subtitle: 'Enjoy your prints!',
        icon: Icons.inventory_2_rounded,
      );
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _promptForOtp(String email) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm collection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter the OTP sent to ${email.isEmpty ? 'your email' : email}.'),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(hintText: '1234'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
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
      case OrderStatus.pending:
        return FilledButton.icon(
          icon: const Icon(Icons.payment_rounded, size: 20),
          label: Text(_busy ? 'Processing…' : 'Pay ${rupees(order.cost)}'),
          onPressed: _busy ? null : () => _payNow(order),
        );
      case OrderStatus.ready:
        return FilledButton.icon(
          icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
          label: Text(_busy ? 'Processing…' : 'Request Collection'),
          onPressed: _busy ? null : () => _requestAndConfirmCollection(order),
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
      case OrderStatus.cancelled:
      case OrderStatus.failed:
        return const SizedBox.shrink();
    }
  }
}
