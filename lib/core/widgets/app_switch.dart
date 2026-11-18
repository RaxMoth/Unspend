import 'package:flutter/cupertino.dart';

import '../theme/theme.dart';

/// The app's on/off switch: an iOS switch with a full-size tap target and a
/// single, labelled accessibility node.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.semanticLabel,
  });

  final bool value;

  /// Null disables the switch.
  final ValueChanged<bool>? onChanged;

  /// Track colour when on; the brand colour when null.
  final Color? activeColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onChanged != null;
    return Semantics(
      container: true,
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppSizes.tapTarget + AppSpacing.sm,
            minHeight: AppSizes.tapTarget,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            // Purely visual: taps and accessibility are handled above so the
            // whole target responds.
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: CupertinoSwitch(
                  value: value,
                  onChanged: enabled ? (_) {} : null,
                  activeTrackColor: activeColor ?? colors.accent,
                  inactiveTrackColor: colors.border,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
