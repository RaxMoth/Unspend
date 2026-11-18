import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// A thin, rounded bar showing how far something has come (0 to 1).
/// Decorative: the number it shows is always also there as text.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({super.key, required this.value, this.color});

  final double value;

  /// Bar colour; the brand colour when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: AppRadius.bar,
        child: LinearProgressIndicator(
          value: value.clamp(0, 1).toDouble(),
          minHeight: AppSizes.progressBarHeight,
          backgroundColor: context.colors.border,
          valueColor: AlwaysStoppedAnimation(color ?? context.colors.accent),
        ),
      ),
    );
  }
}
