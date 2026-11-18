import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// A small label on a tint of its colour: a rule a profile uses, a count,
/// a value.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.prominent = false,
  });

  final String label;

  /// Colour of the chip. It is adjusted for readability, so a profile's raw
  /// colour can be passed.
  final Color color;
  final IconData? icon;

  /// Larger, bold text — for a value rather than a tag.
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final foreground = context.colors.readable(color);
    final text = context.text;
    return Container(
      padding: prominent
          ? const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            )
          : AppInsets.chip,
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.tint),
        borderRadius: AppRadius.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSizes.iconXs, color: foreground),
            Gap.hXs,
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: (prominent ? text.body : text.micro).strong.tone(
                foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
