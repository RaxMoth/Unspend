import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Shows or hides [child] by growing or shrinking the space it takes, so
/// the content below slides instead of jumping. Instant when the user
/// asked the system to reduce motion.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = visible ? child : const SizedBox(width: double.infinity);
    final duration = context.motion(AppDurations.medium);
    // A size animation of no length must not be started at all: it would
    // finish in the middle of the layout pass that started it.
    if (duration == Duration.zero) return content;
    return AnimatedSize(
      duration: duration,
      curve: AppCurves.standard,
      alignment: Alignment.topCenter,
      child: content,
    );
  }
}
