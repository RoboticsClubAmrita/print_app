import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

/// Shared tooltip action for every coach-mark `Showcase` in the app.
///
/// Renders as a small black "Next" button inside the tooltip, with a tiny
/// step-count label (e.g. "1/16") as a subscript just to its right —
/// outside the button's background, not part of its text.
List<TooltipActionButton> nextTooltipActions(
  BuildContext context, {
  required int step,
  required int total,
}) {
  final showBack = step > 1;

  return [
    if (showBack)
      TooltipActionButton(
        type: TooltipDefaultActionType.previous,
        name: 'Back',
        backgroundColor: Colors.white,
        textStyle: const TextStyle(
          color: Colors.black,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
        onTap: () => ShowCaseWidget.of(context).previous(),
      ),
    TooltipActionButton.custom(
      button: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Material(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => ShowCaseWidget.of(context).next(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                child: Text(
                  'Next',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '$step/$total',
              style: const TextStyle(
                color: Colors.black45,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  ];
}

/// Keeps the button tucked in the same spot on every tooltip.
const tooltipNextActionConfig = TooltipActionConfig(
  alignment: MainAxisAlignment.end,
  position: TooltipActionPosition.inside,
  gapBetweenContentAndAction: 10,
);

/// Lets the app-level `ShowCaseWidget`'s `onFinish` callback (set once in
/// `main.dart`) notify whichever screen owns the tour (`ShellScreen`) that
/// the tour finished — without threading a callback through the widget tree.
class TourCoordinator {
  static VoidCallback? onFinish;

  /// Set by `ShellScreen`; invoked from Profile -> About PrintEase to run the
  /// walkthrough again from step 1. Null when no shell is mounted.
  static VoidCallback? onReplay;

  /// Fired as each coach mark begins, so the screen that owns the scroll view
  /// can bring the target into view itself. The package's own auto-scroll
  /// cannot: it positions by layout, and the order form is painted 46px above
  /// where it lays out (a `Transform.translate`), so its scroll landed short
  /// and visibly corrected itself on the mid-form steps.
  static void Function(GlobalKey key)? onStepStart;

  /// Total coach-mark steps in the first-login tour (Home tab + the
  /// bottom nav pill). Update this if you add/remove Showcase steps there.
  static const int totalSteps = 10;
}

/// Drop-in replacement for [Showcase] that fixes two app-wide issues:
/// 1. Highlights must snap directly to their target — no glide/scale
///    animation between steps (this was the cause of the spotlight
///    appearing to "keep moving up" on repeated Back presses).
/// 2. Uses the shared [_tourScrollDuration]-equivalent scroll timing so
///    auto-scroll finishes before the overlay is drawn.
class AppShowcase extends Showcase {
  AppShowcase({
    required super.key,
    required super.child,
    super.title,
    super.description,
    super.targetShapeBorder,
    super.tooltipActions,
    super.tooltipActionConfig,
  }) : super(
          disableMovingAnimation: true,
          disableScaleAnimation: true,
          // scrollDuration removed — it doesn't belong here
        );
}