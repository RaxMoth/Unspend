import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// Builds its child with the horizontal inset that keeps content at most
/// [AppSizes.maxContentWidth] wide and at least [minimum] away from the
/// edges.
///
/// The scroll view itself stays full width (so it can be dragged anywhere);
/// only its content is inset:
///
/// ```dart
/// ContentGutter(
///   builder: (context, gutter) => ListView(
///     padding: EdgeInsets.symmetric(horizontal: gutter),
///     children: [...],
///   ),
/// )
/// ```
class ContentGutter extends StatelessWidget {
  const ContentGutter({
    super.key,
    this.minimum = AppInsets.screenGutter,
    required this.builder,
  });

  final double minimum;
  final Widget Function(BuildContext context, double gutter) builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => builder(
      context,
      math.max(minimum, (constraints.maxWidth - AppSizes.maxContentWidth) / 2),
    ),
  );
}
