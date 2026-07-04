import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/pricing.dart';
import '../models/print_order.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/fx.dart';
import '../widgets/pill_toggle.dart';
import '../widgets/status_chip.dart';
import '../widgets/ticket_card.dart';
import 'order_detail_screen.dart';

/// Orders tab: dark screen with boarding-pass style order tickets,
/// mirroring the "Result Search" flight reference screen.
class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final orders = _filter == 0 ? state.activeOrders : state.historyOrders;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 14),
            const Text(
              'My Orders',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${state.activeOrders.length} active • ${state.historyOrders.length} collected',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 18),
            PillToggle(
              options: const ['Active', 'History'],
              selectedIndex: _filter,
              onChanged: (i) => setState(() => _filter = i),
              onDark: true,
            ),
            const SizedBox(height: 18),
            Expanded(
              child: orders.isEmpty
                  ? FadeSlideIn(
                      key: ValueKey('empty-$_filter'),
                      from: const Offset(0, 0.04),
                      child: _emptyState(),
                    )
                  : ListView.separated(
                      key: ValueKey('list-$_filter'),
                      padding: const EdgeInsets.only(bottom: 120),
                      itemCount: orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, i) => FadeSlideIn(
                        delay: Duration(milliseconds: 50 * (i < 6 ? i : 6)),
                        child: _orderTicket(context, orders[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.print_disabled_outlined,
              color: Colors.white54,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _filter == 0 ? 'No active orders' : 'No collected orders yet',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderTicket(BuildContext context, PrintOrder o) {
    return TicketCard(
      notchColor: AppColors.black,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id)),
      ),
      top: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.chip,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(_fileIcon(o.fileName), size: 22),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${o.id} • ${o.fileSizeKb} KB',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(status: o.status),
        ],
      ),
      bottom: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _metaChip(
                    Icons.calendar_today_rounded,
                    DateFormat('MMM d').format(o.scheduledAt),
                  ),
                  const SizedBox(width: 8),
                  _metaChip(
                    Icons.copy_rounded,
                    '${o.pages} pg × ${o.copies}',
                  ),
                  const SizedBox(width: 8),
                  _metaChip(
                    Icons.flip_to_back_rounded,
                    o.side == PrintSide.single ? '1-side' : '2-side',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: rupees(o.cost),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                  ),
                ),
                const TextSpan(
                  text: ' /total',
                  style: TextStyle(
                    fontSize: 11,
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

  Widget _metaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.black),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  IconData _fileIcon(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf_outlined,
      'ppt' || 'pptx' => Icons.slideshow_outlined,
      'doc' || 'docx' => Icons.article_outlined,
      'jpg' || 'jpeg' || 'png' => Icons.image_outlined,
      _ => Icons.description_outlined,
    };
  }
}
