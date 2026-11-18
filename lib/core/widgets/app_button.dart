import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// A full-width button for the main action of a screen or sheet.
///
/// [AppButton.primary] is filled (in the brand colour unless [color] is
/// given); [AppButton.secondary] is outlined, for the quieter alternative.
/// The label wraps instead of overflowing, and while [loading] the button
/// shows a spinner and ignores taps.
class AppButton extends StatelessWidget {
  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.loading = false,
  }) : _filled = true;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  }) : _filled = false,
       color = null;

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Fill colour of a primary button, e.g. a profile's colour.
  final Color? color;
  final bool loading;
  final bool _filled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onPressed != null && !loading;

    final FilledColors palette = _filled
        ? (color == null
              ? (fill: colors.accentFill, onFill: colors.onAccentFill)
              : colors.filled(color!))
        : (fill: colors.surface, onFill: colors.textSecondary);
    final foreground = enabled || loading
        ? palette.onFill
        : palette.onFill.withValues(alpha: AppOpacity.disabled);

    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: enabled
            ? () {
                AppHaptics.tap();
                onPressed!();
              }
            : null,
        style: TextButton.styleFrom(
          backgroundColor: palette.fill,
          disabledBackgroundColor: loading
              ? palette.fill
              : palette.fill.withValues(alpha: AppOpacity.disabled),
          foregroundColor: foreground,
          disabledForegroundColor: foreground,
          padding: AppInsets.button,
          minimumSize: const Size.fromHeight(AppSizes.tapTarget),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.control,
            side: _filled ? BorderSide.none : BorderSide(color: colors.border),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading) ...[
              SizedBox.square(
                dimension: AppSizes.iconSm,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              ),
              Gap.hSm,
            ] else if (icon != null) ...[
              Icon(icon, size: AppSizes.iconSm, color: foreground),
              Gap.hSm,
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: context.text.subheading.tone(foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
