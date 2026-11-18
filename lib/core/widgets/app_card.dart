import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// The app's surface for grouped content: rounded, hairline border.
///
///  • plain — a neutral surface;
///  • [tint] — highlighted in a colour (soft wash and outline), for
///    something that is on, selected or needs attention;
///  • [inset] — a quieter, smaller-radius tile for use inside a sheet or
///    another card;
///  • [gradient] — a custom background instead of a flat colour.
///
/// With [onTap] the whole card is a button with ink feedback.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.tint,
    this.outline,
    this.gradient,
    this.inset = false,
    this.emphasized = false,
    this.padding = AppInsets.card,
    this.onTap,
    this.excludeTapFromSemantics = false,
  });

  final Widget child;

  /// Colour the card is highlighted in. Null for a neutral card.
  final Color? tint;

  /// Border colour, when it should differ from what [tint] implies.
  final Color? outline;

  final Gradient? gradient;
  final bool inset;

  /// A slightly heavier outline, for the selected one of several cards.
  final bool emphasized;

  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Set when an ancestor or descendant already describes the tap to
  /// assistive technology.
  final bool excludeTapFromSemantics;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = inset ? AppRadius.control : AppRadius.card;
    final base = inset ? colors.background : colors.surface;
    final fill = tint == null
        ? base
        : Color.alphaBlend(tint!.withValues(alpha: AppOpacity.wash), base);
    final border =
        outline ??
        (tint == null
            ? colors.border
            : tint!.withValues(alpha: AppOpacity.outline));

    final content = Ink(
      decoration: BoxDecoration(
        color: gradient == null ? fill : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(
          color: border,
          width: emphasized ? AppSizes.emphasisBorderWidth : 1,
        ),
      ),
      padding: padding,
      child: child,
    );

    return Material(
      type: MaterialType.transparency,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              excludeFromSemantics: excludeTapFromSemantics,
              child: content,
            ),
    );
  }
}
