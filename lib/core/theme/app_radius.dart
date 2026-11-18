import 'package:flutter/widgets.dart';

/// Corner radii. Containers (cards, sheets, dialogs) are rounder than the
/// controls inside them.
abstract final class AppRadius {
  /// Progress bars and other thin shapes.
  static const double xs = 4;

  /// Chips, badges, checkboxes.
  static const double sm = 8;

  /// Controls: buttons, text fields, tiles.
  static const double md = 12;

  /// Containers: cards, sheets, dialogs.
  static const double lg = 16;

  /// Large icon tiles.
  static const double xl = 20;

  static const bar = BorderRadius.all(Radius.circular(xs));
  static const chip = BorderRadius.all(Radius.circular(sm));
  static const control = BorderRadius.all(Radius.circular(md));
  static const card = BorderRadius.all(Radius.circular(lg));
  static const tile = BorderRadius.all(Radius.circular(xl));
  static const sheet = BorderRadius.vertical(top: Radius.circular(lg));

  static const controlShape = RoundedRectangleBorder(borderRadius: control);
  static const cardShape = RoundedRectangleBorder(borderRadius: card);
  static const sheetShape = RoundedRectangleBorder(borderRadius: sheet);
}
