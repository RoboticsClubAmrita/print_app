import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_theme.dart';

/// First-run walkthrough — a port of the website's `CoachTour`
/// (print_integrated/src/user/components/app/CoachTour.tsx) so both apps
/// teach the same thing the same way:
///
///  * the screen dims, with a rounded cutout around the current target that
///    glides from one target to the next,
///  * a white card carries the step's title, a one-line description, a ✕ to
///    skip, Back / Next (Done on the last step) and an `n/N` counter,
///  * the card sits below the target when there is room, above it otherwise,
///  * tapping the dimmed area does nothing — skipping is the ✕ (or the system
///    back button), never an accidental tap.

/// One step: the copy shown, plus the widget it points at.
class TourStep {
  const TourStep({
    required this.target,
    required this.title,
    required this.description,
  });

  /// Key of the widget to spotlight (wrap it in a `KeyedSubtree`).
  final GlobalKey target;
  final String title;
  final String description;
}

/// The walkthrough copy, shared word for word with the website
/// (print_integrated/src/user/lib/tourSteps.ts). Keyed by the same ids.
const tourCopy = <String, (String, String)>{
  'tour-upload': (
    'Upload Your Document',
    'Pick any PDF, Word doc or image — we detect the page count instantly.',
  ),
  'tour-side': (
    'Single or Double-Sided',
    'Double-sided fits two pages per sheet — cheaper and greener for long documents.',
  ),
  'tour-pages': (
    'Pick Specific Pages',
    'Print every page, or tap in to choose a custom range like 1-5, 8.',
  ),
  'tour-copies': (
    'Set Your Copies',
    'Use + and – to change how many copies you need.',
  ),
  'tour-schedule': (
    'Choose When to Print',
    'Print right now, or schedule your order for a later time.',
  ),
  'tour-location': (
    'Choose Your Location',
    'Pick which print stack should receive your order.',
  ),
  'tour-total': (
    'Estimated Total',
    'Your live cost updates instantly as you adjust pages, copies and sides.',
  ),
  'tour-submit': (
    'Place Your Order',
    "When you're ready, tap here to review and confirm your print job.",
  ),
  'tour-nav': (
    'Switch Between Tabs',
    'Jump to Orders, Billing or Profile anytime using this bar.',
  ),
};

/// Website step order.
const tourOrder = [
  'tour-upload',
  'tour-side',
  'tour-pages',
  'tour-copies',
  'tour-schedule',
  'tour-location',
  'tour-total',
  'tour-submit',
  'tour-nav',
];

/// How the walkthrough ended.
enum TourResult {
  /// Ran to the end with Done — the caller may follow up (welcome dialog).
  finished,

  /// Skipped with ✕ or the back button — nothing should follow.
  skipped,
}

/// Lets Profile → About PrintEase ask whichever shell is mounted to replay
/// the walkthrough, without threading a callback through the widget tree.
class TourCoordinator {
  static VoidCallback? onReplay;
}

class CoachTour {
  /// Runs the walkthrough above everything (including the bottom nav) and
  /// resolves when it ends.
  static Future<TourResult> show(
      BuildContext context, List<TourStep> steps) async {
    if (steps.isEmpty) return TourResult.skipped;
    final result =
        await Navigator.of(context, rootNavigator: true).push<TourResult>(
      PageRouteBuilder<TourResult>(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (_, __, ___) => _CoachTourView(steps: steps),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    return result ?? TourResult.skipped;
  }
}

// Same geometry as the website.
const _pad = 8.0;
const _cutoutRadius = 14.0;
const _cardMaxWidth = 320.0;
const _edge = 16.0;
const _gap = 16.0;
const _minSpaceBelow = 200.0;
const _dim = Color(0xB80A0A0A); // rgba(10,10,10,0.72)
const _glide = Duration(milliseconds: 200);
const _scrollDuration = Duration(milliseconds: 300);

/// How long to keep re-measuring a step's target after the step changes —
/// long enough to follow the scroll and find a target that mounts late.
/// After that the ticker idles until the next step (no per-frame work while
/// the user reads the card).
const _followFor = Duration(milliseconds: 1000);

class _CoachTourView extends StatefulWidget {
  const _CoachTourView({required this.steps});

  final List<TourStep> steps;

  @override
  State<_CoachTourView> createState() => _CoachTourViewState();
}

class _CoachTourViewState extends State<_CoachTourView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int _index = 0;

  /// Where the target is right now (re-measured every frame while following,
  /// so the cutout tracks it as the page scrolls).
  Rect? _measured;

  /// Where the cutout was when the step changed — it glides from here.
  Rect? _from;

  /// Frame time of the latest tick. Taken from the scheduler rather than
  /// the ticker's `elapsed` (which resets when the ticker restarts) or a
  /// Stopwatch (which ignores test clocks).
  Duration _now = Duration.zero;
  Duration _stepStartedAt = Duration.zero;

  /// Set by a step change; the next frame stamps [_stepStartedAt].
  bool _stepStartPending = true;

  /// Whether the previous tick was still gliding — the frame after a glide
  /// ends must still rebuild, or the cutout freezes just short of its target.
  bool _wasGliding = false;

  /// The target is scrolled into view once per step, as soon as it exists.
  bool _scrolledForStep = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Screen size/rotation changed: the target moved, follow it again.
    MediaQuery.sizeOf(context);
    _follow();
  }

  /// (Re)start tracking the current target for [_followFor].
  void _follow() {
    if (!_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  TourStep get _step => widget.steps[_index];

  void _onTick(Duration _) {
    _now = SchedulerBinding.instance.currentFrameTimeStamp;
    if (_stepStartPending) {
      _stepStartPending = false;
      _stepStartedAt = _now;
    }
    final rect = _measureTarget();
    if (rect != null && !_scrolledForStep) {
      _scrolledForStep = true;
      final ctx = _step.target.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: _scrollDuration,
          curve: Curves.easeInOut,
        );
      }
    }
    final gliding = _now - _stepStartedAt < _glide;
    // A previous step's rect is kept while the next target is located, so
    // the spotlight never blinks out between steps.
    final animate = gliding || _wasGliding;
    _wasGliding = gliding;
    if (rect != null && (rect != _measured || animate)) {
      setState(() => _measured = rect);
    } else if (animate) {
      setState(() {});
    }
    if (_now - _stepStartedAt >= _followFor && !gliding) _ticker.stop();
  }

  Rect? _measureTarget() {
    final box = _step.target.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// The cutout actually drawn: easing from the previous target to this one.
  Rect? get _displayed {
    final to = _measured;
    final from = _from;
    if (to == null || from == null) return to;
    final t = ((_now - _stepStartedAt).inMicroseconds / _glide.inMicroseconds)
        .clamp(0.0, 1.0);
    return Rect.lerp(from, to, Curves.easeOutCubic.transform(t));
  }

  void _goTo(int index) {
    setState(() {
      _from = _displayed;
      _stepStartPending = true;
      _scrolledForStep = false;
      _index = index;
    });
    _follow();
  }

  void _close(TourResult result) => Navigator.of(context).pop(result);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;
    final rect = _displayed;
    final isFirst = _index == 0;
    final isLast = _index == widget.steps.length - 1;

    final cardWidth = math.min(_cardMaxWidth, screen.width - _edge * 2);
    final spaceBelow =
        rect == null ? 0.0 : screen.height - media.padding.bottom - rect.bottom;
    final placeBelow = rect == null || spaceBelow > _minSpaceBelow;
    final left = rect == null
        ? (screen.width - cardWidth) / 2
        : rect.left.clamp(_edge, screen.width - cardWidth - _edge).toDouble();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close(TourResult.skipped);
      },
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Dim + cutout. Also swallows taps on the dimmed area without
            // ending the walkthrough.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: CustomPaint(painter: _MaskPainter(rect)),
              ),
            ),
            Positioned(
              left: left,
              width: cardWidth,
              top: placeBelow
                  ? (rect == null
                      ? screen.height / 3
                      : rect.bottom + _pad + _gap)
                  : null,
              bottom:
                  placeBelow ? null : screen.height - rect.top + _pad + _gap,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(_index),
                tween: Tween(begin: 0, end: 1),
                duration: _glide,
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * (placeBelow ? -8 : 8)),
                    child: child,
                  ),
                ),
                child: _TourCard(
                  step: _step,
                  index: _index,
                  total: widget.steps.length,
                  onBack: isFirst ? null : () => _goTo(_index - 1),
                  onNext: isLast
                      ? () => _close(TourResult.finished)
                      : () => _goTo(_index + 1),
                  isLast: isLast,
                  onSkip: () => _close(TourResult.skipped),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaskPainter extends CustomPainter {
  _MaskPainter(this.target);

  final Rect? target;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    final t = target;
    if (t != null) {
      path.addRRect(
        RRect.fromRectAndRadius(
            t.inflate(_pad), const Radius.circular(_cutoutRadius)),
      );
    }
    canvas.drawPath(path, Paint()..color = _dim);
  }

  @override
  bool shouldRepaint(_MaskPainter old) => old.target != target;
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.step,
    required this.index,
    required this.total,
    required this.onBack,
    required this.onNext,
    required this.isLast,
    required this.onSkip,
  });

  final TourStep step;
  final int index;
  final int total;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final bool isLast;
  final VoidCallback onSkip;

  static const _buttonText =
      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700);
  static const _buttonPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 8);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 50,
            offset: const Offset(0, 25),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Transform.translate(
                offset: const Offset(6, -6),
                child: Semantics(
                  button: true,
                  label: 'Skip the walkthrough',
                  child: InkResponse(
                    onTap: onSkip,
                    radius: 18,
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(Icons.close_rounded,
                          size: 16, color: Colors.black38),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            step.description,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.55,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (onBack != null) ...[
                InkWell(
                  onTap: onBack,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: _buttonPadding,
                    child: Text('Back',
                        style: _buttonText.copyWith(color: AppColors.black)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Material(
                color: AppColors.black,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: onNext,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: _buttonPadding,
                    child: Text(
                      isLast ? 'Done' : 'Next',
                      style: _buttonText.copyWith(color: AppColors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '${index + 1}/$total',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.black38,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
