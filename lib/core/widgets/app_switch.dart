import 'package:flutter/cupertino.dart';

import '../theme/design_tokens.dart';

/// The app's on/off switch: an iOS switch with a tap target of at least
/// 48 × 48 points and a single, labelled accessibility node.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = kAccent,
    this.semanticLabel,
  });

  final bool value;

  /// Null disables the switch.
  final ValueChanged<bool>? onChanged;
  final Color activeColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
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
          constraints: const BoxConstraints(minWidth: 56, minHeight: 48),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            // Purely visual: taps and accessibility are handled above so the
            // whole 48pt area responds.
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: CupertinoSwitch(
                  value: value,
                  onChanged: enabled ? (_) {} : null,
                  activeTrackColor: activeColor,
                  inactiveTrackColor: kBorder,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
