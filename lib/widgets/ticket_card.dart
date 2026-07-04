import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'fx.dart';

/// White rounded card with side notches and a dashed divider between
/// [top] and [bottom], recreating the boarding-pass style order cards
/// from the flight results reference screen.
class TicketCard extends StatelessWidget {
  final Widget top;
  final Widget bottom;

  /// Color of the surface behind the card — the notches are "cut out"
  /// by painting circles of this color over the card edges.
  final Color notchColor;
  final VoidCallback? onTap;

  const TicketCard({
    super.key,
    required this.top,
    required this.bottom,
    required this.notchColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: top,
            ),
            SizedBox(
              height: 24,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Center(child: _DashedLine()),
                  ),
                  Positioned(left: -12, top: 0, child: _notch()),
                  Positioned(right: -12, top: 0, child: _notch()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: bottom,
            ),
          ],
        ),
      ),
    );
  }

  Widget _notch() => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: notchColor, shape: BoxShape.circle),
      );
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(double.infinity, 1.5),
      painter: _DashPainter(),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.5;
    const dash = 6.0;
    const gap = 5.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
