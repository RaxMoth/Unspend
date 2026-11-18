import 'package:flutter/widgets.dart';

/// How long things take to move.
abstract final class AppDurations {
  /// Selection states: a swatch, a checkbox.
  static const fast = Duration(milliseconds: 150);

  /// Content appearing or changing size; switches.
  static const medium = Duration(milliseconds: 250);

  /// Moving between pages.
  static const slow = Duration(milliseconds: 300);

  /// Pause after the last keystroke before a text edit is saved.
  static const typingDebounce = Duration(milliseconds: 500);
}

/// How things move.
abstract final class AppCurves {
  static const standard = Curves.easeInOut;
  static const enter = Curves.easeOut;
}

extension AppMotion on BuildContext {
  /// [duration], or no time at all when the user asked the system to reduce
  /// motion (Accessibility → Motion → Reduce Motion).
  Duration motion(Duration duration) =>
      MediaQuery.disableAnimationsOf(this) ? Duration.zero : duration;
}
