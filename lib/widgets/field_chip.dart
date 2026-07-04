import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Gray rounded form chip with a small label above a bold value,
/// matching the "From / To / Departure Date" chips in the reference.
class FieldChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData? trailingIcon;
  final VoidCallback? onTap;
  final bool valueIsPlaceholder;

  const FieldChip({
    super.key,
    required this.label,
    required this.value,
    this.trailingIcon,
    this.onTap,
    this.valueIsPlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.chip,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutQuart,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.35),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.centerLeft,
                        children: [...previous, if (current != null) current],
                      ),
                      child: Text(
                        value,
                        key: ValueKey(value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: valueIsPlaceholder
                              ? AppColors.textSecondary
                              : AppColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 10),
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Icon(trailingIcon, size: 19, color: AppColors.black),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A field chip with round minus/plus steppers, used for pages and copies.
class StepperChip extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  const StepperChip({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 1,
  });

  void _set(int v) {
    HapticFeedback.selectionClick();
    onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 9, 10),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, if (current != null) current],
                  ),
                  child: Text(
                    '$value',
                    key: ValueKey(value),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _RoundIconButton(
            icon: Icons.remove,
            onTap: value > min ? () => _set(value - 1) : null,
          ),
          const SizedBox(width: 5),
          _RoundIconButton(
            icon: Icons.add,
            onTap: () => _set(value + 1),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _RoundIconButton({required this.icon, this.onTap});

  @override
  State<_RoundIconButton> createState() => _RoundIconButtonState();
}

class _RoundIconButtonState extends State<_RoundIconButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 31,
          height: 31,
          decoration: BoxDecoration(
            color: enabled ? AppColors.black : AppColors.border,
            shape: BoxShape.circle,
          ),
          child: Icon(widget.icon, size: 18, color: AppColors.white),
        ),
      ),
    );
  }
}
