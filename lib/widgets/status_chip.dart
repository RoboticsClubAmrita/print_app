import 'package:flutter/material.dart';

import '../models/print_order.dart';
import '../theme/app_theme.dart';

/// Small rounded status chip with a tiny colored state dot — the only
/// accent color in the otherwise black & white design.
class StatusChip extends StatelessWidget {
  final OrderStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (dot, filled) = switch (status) {
      OrderStatus.pending => (AppColors.warning, false),
      OrderStatus.queued => (AppColors.textSecondary, false),
      OrderStatus.printing => (AppColors.warning, true),
      OrderStatus.awaitingStack => (AppColors.warning, false),
      OrderStatus.ready => (AppColors.success, true),
      OrderStatus.collected => (AppColors.success, false),
      OrderStatus.cancelled => (AppColors.textSecondary, false),
      OrderStatus.failed => (AppColors.warning, true),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: filled ? AppColors.black : AppColors.chip,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: filled ? AppColors.white : AppColors.black,
            ),
          ),
        ],
      ),
    );
  }
}
