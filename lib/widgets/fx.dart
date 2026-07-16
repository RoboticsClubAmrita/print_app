import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Shared motion language so every animation in the app moves the same way.
class AppMotion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 340);
  static const Duration slow = Duration(milliseconds: 560);
  static const Curve ease = Curves.easeOutQuart;
  static const Curve spring = Curves.easeOutBack;
}

/// Wraps any child with tactile press feedback: a quick scale-down while
/// the pointer is down plus optional selection haptics on tap.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool haptics;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
    this.haptics = true,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:
          widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp:
          widget.onTap == null ? null : (_) => setState(() => _down = false),
      onTapCancel:
          widget.onTap == null ? null : () => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptics) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// One-shot entrance animation: fades in while sliding up slightly.
/// Use [delay] to stagger siblings.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset from;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.slow,
    this.from = const Offset(0, 0.06),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.ease,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position:
            Tween<Offset>(begin: widget.from, end: Offset.zero).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Animates numeric text (e.g. an estimated total) whenever [value] changes,
/// counting from the previous value to the new one.
class AnimatedCount extends StatelessWidget {
  final int value;
  final String Function(int) format;
  final TextStyle style;

  const AnimatedCount({
    super.key,
    required this.value,
    required this.format,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: AppMotion.normal,
      curve: AppMotion.ease,
      builder: (context, v, _) => Text(format(v.round()), style: style),
    );
  }
}

/// Premium success moment: a dark glass card scales in over a dimmed
/// backdrop with a springy check badge, holds briefly, then dismisses.
Future<void> showSuccessOverlay(
  BuildContext context, {
  required String title,
  String? subtitle,
  IconData icon = Icons.check_rounded,
  Duration hold = const Duration(milliseconds: 3000),
}) async {
  HapticFeedback.mediumImpact();
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    barrierLabel: title,
    transitionDuration: AppMotion.normal,
    pageBuilder: (dialogContext, _, __) {
      bool dismissed = false;
      Future.delayed(hold, () {
        if (dialogContext.mounted && !dismissed) {
          dismissed = true;
          Navigator.of(dialogContext).pop();
        }
      });
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (dialogContext.mounted && !dismissed) {
            dismissed = true;
            Navigator.of(dialogContext).pop();
          }
        },
        child: Center(
          child: _SuccessCard(title: title, subtitle: subtitle, icon: icon),
        ),
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
}


class _SuccessCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;

  const _SuccessCard({required this.title, this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 48),
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
        decoration: BoxDecoration(
          gradient: AppDecor.darkPanelGradient,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: AppMotion.slow,
              curve: AppMotion.spring,
              builder: (context, t, child) =>
                  Transform.scale(scale: t, child: child),
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.black, size: 34),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Wraps [child] with a rotating glowing border while [active] is true —
/// the same "AI is working" look as VS Code's Claude/Copilot loading state.
/// When inactive, [child] is returned unchanged so the widget's normal look
/// is untouched. The border never intercepts touches, so [child] stays
/// interactive (or not) purely based on what its own callbacks do.
class AnimatedGlowBorder extends StatefulWidget {
  final Widget child;
  final bool active;
  final double radius;

  const AnimatedGlowBorder({
    super.key,
    required this.child,
    required this.active,
    this.radius = 22,
  });

  @override
  State<AnimatedGlowBorder> createState() => _AnimatedGlowBorderState();
}

class _AnimatedGlowBorderState extends State<AnimatedGlowBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant AnimatedGlowBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.repeat();
    } else if (!widget.active && oldWidget.active) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _GlowBorderPainter(
                  t: _controller.value,
                  radius: widget.radius,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowBorderPainter extends CustomPainter {
  final double t;
  final double radius;

  _GlowBorderPainter({required this.t, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect =
        RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(radius));
    final rotation = GradientRotation(2 * math.pi * t);

    final sweep = SweepGradient(
      transform: rotation,
      colors: const [
        Colors.transparent,
        Colors.white24,
        Colors.white,
        Colors.white24,
        Colors.transparent,
      ],
      stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
    );

    // Soft bloom underneath the crisp sweep, matching the diffuse glow of
    // the VS Code Claude/Copilot loading border.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = sweep.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = sweep.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(_GlowBorderPainter old) =>
      old.t != t || old.radius != radius;
}

/// Constrains content width on large screens so layouts stay phone-shaped
/// and centered instead of stretching edge to edge.
class ResponsiveFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveFrame({super.key, required this.child, this.maxWidth = 560});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
