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
  Duration hold = const Duration(milliseconds: 1350),
}) async {
  HapticFeedback.mediumImpact();
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    barrierLabel: title,
    transitionDuration: AppMotion.normal,
    pageBuilder: (dialogContext, _, __) {
      Future.delayed(hold, () {
        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
      });
      return Center(
        child: _SuccessCard(title: title, subtitle: subtitle, icon: icon),
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
