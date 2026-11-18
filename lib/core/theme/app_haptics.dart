import 'package:flutter/services.dart';

/// The app's haptic vocabulary. One meaning per pattern, so the same kind
/// of action always feels the same.
abstract final class AppHaptics {
  /// A choice changed: a switch, a swatch, a checkbox, a tab.
  static void selection() => HapticFeedback.selectionClick();

  /// A button was pressed.
  static void tap() => HapticFeedback.lightImpact();

  /// Something took effect: a profile was activated, a value saved.
  static void confirm() => HapticFeedback.mediumImpact();

  /// An action was refused.
  static void reject() => HapticFeedback.heavyImpact();
}
