import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Segmented control with a sliding thumb: the selected option's pill
/// glides between positions instead of just swapping colors.
class PillToggle extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Set true when rendered on a dark background (orders screen).
  final bool onDark;

  const PillToggle({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final n = options.length;
    final thumbAlign = n == 1
        ? Alignment.center
        : Alignment(-1 + 2 * (selectedIndex / (n - 1)), 0);

    return Container(
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.10) : AppColors.chip,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: onDark
              ? Colors.white.withValues(alpha: 0.12)
              : AppColors.border.withValues(alpha: 0.6),
        ),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuart,
            alignment: thumbAlign,
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: onDark ? AppColors.white : AppColors.black,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (i != selectedIndex) {
                        HapticFeedback.selectionClick();
                        onChanged(i);
                      }
                    },
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        style: TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: _textColor(i == selectedIndex),
                        ),
                        child: Text(
                          options[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _textColor(bool selected) {
    if (selected) return onDark ? AppColors.black : AppColors.white;
    return onDark ? Colors.white70 : AppColors.textSecondary;
  }
}
