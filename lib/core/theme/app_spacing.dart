import 'package:flutter/widgets.dart';

/// The spacing scale. Every gap and padding in the app is one of these, so
/// screens line up with each other. Steps follow a 4-point grid.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
}

/// Fixed gaps between widgets: `v…` in a Column, `h…` in a Row.
abstract final class Gap {
  static const vXxs = SizedBox(height: AppSpacing.xxs);
  static const vXs = SizedBox(height: AppSpacing.xs);
  static const vSm = SizedBox(height: AppSpacing.sm);
  static const vMd = SizedBox(height: AppSpacing.md);
  static const vLg = SizedBox(height: AppSpacing.lg);
  static const vXl = SizedBox(height: AppSpacing.xl);
  static const vXxl = SizedBox(height: AppSpacing.xxl);
  static const vHuge = SizedBox(height: AppSpacing.huge);

  static const hXs = SizedBox(width: AppSpacing.xs);
  static const hSm = SizedBox(width: AppSpacing.sm);
  static const hMd = SizedBox(width: AppSpacing.md);
  static const hLg = SizedBox(width: AppSpacing.lg);
}

/// Paddings with a meaning. Prefer these over composing new ones.
abstract final class AppInsets {
  /// Minimum distance between screen content and the screen edge.
  static const double screenGutter = AppSpacing.xl;

  /// Inside a card.
  static const card = EdgeInsets.all(AppSpacing.lg);

  /// Inside a card whose trailing control (switch, icon button) brings its
  /// own touch padding.
  static const cardWithTrailingControl = EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.sm,
    AppSpacing.sm,
    AppSpacing.sm,
  );

  /// Inside a bottom sheet, below the grabber.
  static const sheet = EdgeInsets.fromLTRB(
    AppSpacing.xxl,
    AppSpacing.md,
    AppSpacing.xxl,
    AppSpacing.xxl,
  );

  /// Inside a chip or badge.
  static const chip = EdgeInsets.symmetric(
    horizontal: AppSpacing.sm,
    vertical: AppSpacing.xs,
  );

  /// Inside a text field.
  static const field = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  );

  /// Inside a full-width button.
  static const button = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.lg,
  );
}
