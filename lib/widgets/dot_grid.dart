import 'package:flutter/material.dart';

/// A subtle repeating dot texture used behind dark hero sections to add
/// depth without competing with foreground content.
class DotGrid extends StatelessWidget {
  final Color color;
  final double spacing;
  final double radius;

  const DotGrid({
    super.key,
    required this.color,
    this.spacing = 24,
    this.radius = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotGridPainter(color: color, spacing: spacing, radius: radius),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final Color color;
  final double spacing;
  final double radius;

  _DotGridPainter({
    required this.color,
    required this.spacing,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var y = spacing / 2; y < size.height; y += spacing) {
      for (var x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter old) =>
      old.color != color || old.spacing != spacing || old.radius != radius;
}
