import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// An icon on a soft tile of its own colour — the app's way of giving a
/// card, a screen or an empty state a face.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = medium,
    this.muted = false,
    this.circular = false,
    this.background,
  });

  /// Leading badge of a compact row.
  static const double small = 44;

  /// Leading badge of a card.
  static const double medium = 48;

  /// Leading badge of a headline card.
  static const double large = 56;

  /// At the top of a screen.
  static const double hero = 80;

  /// Illustration of an onboarding page, and its size when space is tight.
  static const double illustration = 100;
  static const double illustrationCompact = 64;

  /// The icon fills half the tile; the corners are a quarter of its size.
  static const double _iconScale = 0.5;
  static const double _cornerScale = 0.25;

  final IconData icon;
  final Color color;

  /// Edge length of the tile. The icon is half as large.
  final double size;

  /// Greyed out: the thing it stands for is switched off.
  final bool muted;

  final bool circular;

  /// Tile colour, when it should not be a tint of [color].
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color:
            background ??
            (muted ? colors.border : color.withValues(alpha: AppOpacity.tint)),
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular
            ? null
            : BorderRadius.circular(size * _cornerScale),
      ),
      child: Icon(
        icon,
        size: size * _iconScale,
        color: muted ? colors.textSecondary : color,
      ),
    );
  }
}
