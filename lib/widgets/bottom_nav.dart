import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Premium floating dock navigation: gradient dark pill with layered
/// shadows; the selected tab expands into a white pill revealing its label.
class FloatingBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const FloatingBottomNav({
    super.key,
    required this.index,
    required this.onTap,
  });

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.receipt_long_rounded, 'Orders'),
    (Icons.account_balance_wallet_rounded, 'Billing'),
    (Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF212127), Color(0xFF0B0B0D)],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 32,
              spreadRadius: -6,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _items.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              _NavItem(
                icon: _items[i].$1,
                label: _items[i].$2,
                selected: i == index,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap(i);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _duration = Duration(milliseconds: 340);
  static const _curve = Curves.easeOutQuart;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: _duration,
          curve: _curve,
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 13),
          decoration: BoxDecoration(
            color: selected ? AppColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                duration: _duration,
                curve: Curves.easeOutBack,
                scale: selected ? 1.0 : 0.92,
                child: Icon(
                  icon,
                  size: 19,
                  color: selected
                      ? AppColors.black
                      : Colors.white.withValues(alpha: 0.55),
                ),
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: _duration,
                  curve: _curve,
                  alignment: Alignment.centerLeft,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 7),
                          child: Text(
                            label,
                            maxLines: 1,
                            style: const TextStyle(
                              color: AppColors.black,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
