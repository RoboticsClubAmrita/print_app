import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The PrintEase app icon, painted from the app's own design language:
/// a crisp white sheet — folded corner, bold printed lines — rising out of
/// the floating dock, on the brand's top-lit dark panel with its dot-grid
/// texture and a single green "ready to collect" status dot.
///
/// [maskable] renders a full-bleed square (no transparent corners) with the
/// motif scaled into the central safe zone, for PWA maskable icons.
class AppIconPainter extends CustomPainter {
  final bool maskable;

  const AppIconPainter({this.maskable = false});

  static const double _base = 512;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / _base;
    canvas.save();
    canvas.scale(s);
    _tile(canvas);
    if (maskable) {
      canvas.translate(_base / 2, _base / 2);
      canvas.scale(0.80);
      canvas.translate(-_base / 2, -_base / 2);
    }
    _motif(canvas);
    canvas.restore();
  }

  void _tile(Canvas canvas) {
    const rect = Rect.fromLTWH(0, 0, _base, _base);
    final gradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.blackSoft, AppColors.black],
      ).createShader(rect);

    if (maskable) {
      canvas.drawRect(rect, gradient);
      _dotGrid(canvas, rect);
      return;
    }

    final tile = RRect.fromRectAndRadius(rect, const Radius.circular(120));
    canvas.save();
    canvas.clipRRect(tile);
    canvas.drawRect(rect, gradient);
    _dotGrid(canvas, rect);
    canvas.restore();
    canvas.drawRRect(
      tile.deflate(3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.white.withValues(alpha: 0.14),
    );
  }

  void _dotGrid(Canvas canvas, Rect rect) {
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.07);
    const spacing = 52.0;
    for (var y = spacing / 2; y < rect.height; y += spacing) {
      for (var x = spacing / 2; x < rect.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 3.4, dot);
      }
    }
  }

  void _motif(Canvas canvas) {
    _sheet(canvas);
    _dockBar(canvas);
  }

  void _sheet(Canvas canvas) {
    const center = Offset(256, 222);
    const w = 250.0, h = 322.0, r = 30.0, fold = 66.0;
    final rect = Rect.fromCenter(center: center, width: w, height: h);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-8 * math.pi / 180);
    canvas.translate(-center.dx, -center.dy);

    // Sheet outline with the top-right corner cut along the fold diagonal.
    final sheet = Path()
      ..moveTo(rect.left + r, rect.top)
      ..lineTo(rect.right - fold, rect.top)
      ..lineTo(rect.right, rect.top + fold)
      ..lineTo(rect.right, rect.bottom - r)
      ..arcToPoint(
        Offset(rect.right - r, rect.bottom),
        radius: const Radius.circular(r),
      )
      ..lineTo(rect.left + r, rect.bottom)
      ..arcToPoint(
        Offset(rect.left, rect.bottom - r),
        radius: const Radius.circular(r),
      )
      ..lineTo(rect.left, rect.top + r)
      ..arcToPoint(
        Offset(rect.left + r, rect.top),
        radius: const Radius.circular(r),
      )
      ..close();

    canvas.drawPath(
      sheet.shift(const Offset(0, 12)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawPath(sheet, Paint()..color = AppColors.white);

    // Folded-over flap.
    final flap = Path()
      ..moveTo(rect.right - fold, rect.top)
      ..lineTo(rect.right - fold, rect.top + fold)
      ..lineTo(rect.right, rect.top + fold)
      ..close();
    canvas.drawPath(flap, Paint()..color = const Color(0xFFE2E2E8));
    canvas.drawLine(
      Offset(rect.right - fold, rect.top),
      Offset(rect.right, rect.top + fold),
      Paint()
        ..color = const Color(0xFFCFCFD6)
        ..strokeWidth = 3,
    );

    // Printed lines: bold w800-type rhythm, one quiet gray line.
    void line(double y, double width, Color color) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left + 42, y, width, 26),
          const Radius.circular(13),
        ),
        Paint()..color = color,
      );
    }

    line(rect.top + 92, 118, const Color(0xFF17171B));
    line(rect.top + 144, 166, const Color(0xFF17171B));
    line(rect.top + 196, 92, const Color(0xFFC9C9CF));

    canvas.restore();
  }

  void _dockBar(Canvas canvas) {
    final barRect = Rect.fromCenter(
      center: const Offset(256, 366),
      width: 332,
      height: 82,
    );
    final bar = RRect.fromRectAndRadius(barRect, const Radius.circular(41));

    // Depth halo so the dock reads as floating in front of the sheet.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        barRect.translate(0, 2).inflate(4),
        const Radius.circular(45),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawRRect(
      bar,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2C2C33), Color(0xFF121216)],
        ).createShader(barRect),
    );
    canvas.drawRRect(
      bar.deflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white.withValues(alpha: 0.16),
    );

    // The single brand accent: the "ready to collect" dot.
    canvas.drawCircle(
      const Offset(148, 366),
      12,
      Paint()..color = AppColors.success,
    );
    canvas.drawCircle(
      const Offset(148, 366),
      20,
      Paint()..color = AppColors.success.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(covariant AppIconPainter oldDelegate) =>
      oldDelegate.maskable != maskable;
}

/// The icon as a widget, for in-app brand usage (e.g. the BrandMark tile).
class AppIconTile extends StatelessWidget {
  final double size;

  const AppIconTile({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const AppIconPainter(),
    );
  }
}
