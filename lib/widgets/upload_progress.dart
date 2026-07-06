import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'fx.dart';

/// Shows a premium dark-panel overlay while a document upload + page-count
/// analysis is in progress. The overlay is non-dismissible; the caller must
/// pop it via the returned [OverlayHandle.dismiss] once the work finishes.
class OverlayHandle {
  final BuildContext _dialogContext;
  bool _dismissed = false;

  OverlayHandle._(this._dialogContext);

  void dismiss() {
    if (!_dismissed && _dialogContext.mounted) {
      _dismissed = true;
      Navigator.of(_dialogContext).pop();
    }
  }
}

/// Opens the upload overlay and returns a handle the caller uses to close it.
Future<OverlayHandle> showUploadOverlay(
  BuildContext context, {
  required String fileName,
}) async {
  late OverlayHandle handle;
  // We don't await the dialog — it stays open until the caller dismisses.
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    barrierLabel: 'Uploading',
    transitionDuration: AppMotion.normal,
    pageBuilder: (dialogContext, _, __) {
      handle = OverlayHandle._(dialogContext);
      return Center(
        child: _UploadCard(fileName: fileName),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: AppMotion.spring);
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: curved, child: child),
      );
    },
  );
  // Give the dialog a frame to build so the handle is assigned.
  await Future.delayed(const Duration(milliseconds: 50));
  return handle;
}

class _UploadCard extends StatefulWidget {
  final String fileName;
  const _UploadCard({required this.fileName});

  @override
  State<_UploadCard> createState() => _UploadCardState();
}

class _UploadCardState extends State<_UploadCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  /// Staged caption: starts with 'Uploading document…', switches after 1.5s.
  String _caption = 'Uploading document…';
  bool _switched = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && !_switched) {
        _switched = true;
        setState(() => _caption = 'Analyzing pages…');
      }
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 48),
        padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
        decoration: AppDecor.darkPanel(radius: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: AnimatedBuilder(
                animation: _spin,
                builder: (context, _) => CustomPaint(
                  painter: _RingPainter(progress: _spin.value),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              widget.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: AppMotion.fast,
              child: Text(
                _caption,
                key: ValueKey(_caption),
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws a monochrome spinning arc ring.
class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Track ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    // Spinning arc
    final sweep = 0.7 * pi;
    final startAngle = 2 * pi * progress - pi / 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      Paint()
        ..color = AppColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
