import 'package:flutter/material.dart';
import 'package:unspend/core/theme/theme.dart';

/// Dims its child and makes it unresponsive while [locked] — for the
/// settings that cannot change while a profile is active.
class LockedSection extends StatelessWidget {
  const LockedSection({super.key, required this.locked, required this.child});

  final bool locked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: locked,
      child: AnimatedOpacity(
        duration: context.motion(AppDurations.medium),
        opacity: locked ? AppOpacity.disabled : 1,
        child: child,
      ),
    );
  }
}
