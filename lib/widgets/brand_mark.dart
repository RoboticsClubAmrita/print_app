import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_icon.dart';

/// The PrintEase logo lockup: the painted app icon beside the wordmark.
/// The wordmark adapts to dark or light backgrounds; the icon tile is the
/// same artwork as the launcher icon.
class BrandMark extends StatelessWidget {
  final bool onDark;

  const BrandMark({super.key, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? AppColors.white : AppColors.black;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppIconTile(size: 40),
        const SizedBox(width: 10),
        Text(
          'PrintEase',
          style: TextStyle(
            color: fg,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}
