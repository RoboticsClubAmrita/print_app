import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

/// Shared tooltip action for every coach-mark `Showcase` in the app.
///
/// Renders as a small black "Next" button inside the tooltip. Tapping it
/// calls `ShowCaseWidget.of(context).next()`, which advances the overlay
/// to the *next* key in the list passed to `startShowCase(...)` — so the
/// arrow ends up pointing at the next feature instead of the tooltip
/// just closing.
List<TooltipActionButton> nextTooltipActions(BuildContext context) => [
      TooltipActionButton(
        type: TooltipDefaultActionType.next,
        name: 'Next',
        backgroundColor: Colors.black,
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
        onTap: () => ShowCaseWidget.of(context).next(),
      ),
    ];

/// Keeps the button tucked in the same spot on every tooltip.
const tooltipNextActionConfig = TooltipActionConfig(
  alignment: MainAxisAlignment.end,
  position: TooltipActionPosition.inside,
  gapBetweenContentAndAction: 10,
);

/// Lets the app-level `ShowCaseWidget.onFinish` callback (set once in
/// `main.dart`) notify whichever screen owns tab-to-tab tour chaining
/// (`ShellScreen`) that a tour sequence just completed — without threading
/// a callback through the widget tree.
class TourCoordinator {
  static VoidCallback? onFinish;
}