/// Fixed sizes of things that are not spacing: icons, touch targets, limits
/// on content width.
abstract final class AppSizes {
  // ── Icons ──────────────────────────────────────────────────────────────
  /// Inline with caption text.
  static const double iconXs = 14;

  /// Inline with body text; status indicators.
  static const double iconSm = 18;

  /// Leading icons of rows and cards.
  static const double iconMd = 20;

  /// Standalone icons: toolbar buttons, list leading icons.
  static const double iconLg = 24;

  /// The app mark and the floating button's glyph.
  static const double iconXl = 28;

  /// Inside the large tile at the top of a profile.
  static const double iconHero = 40;

  /// Illustration of an empty state.
  static const double iconIllustration = 64;

  // ── Touch ──────────────────────────────────────────────────────────────
  /// Every tappable thing is at least this tall and wide (Apple asks for
  /// 44 pt; 48 leaves a margin and matches Material's default).
  static const double tapTarget = 48;

  // ── Layout ─────────────────────────────────────────────────────────────
  /// Widest the content gets. A phone in landscape is far wider than a
  /// comfortable line of text, so content is centred instead of stretched.
  static const double maxContentWidth = 560;

  /// Space left below a list so its last item clears the floating button.
  static const double floatingButtonClearance = 104;

  /// Height of the grabber at the top of a sheet, and its width.
  static const double grabberHeight = 4;
  static const double grabberWidth = 40;

  /// Thickness of a progress bar.
  static const double progressBarHeight = 4;

  /// Width of the outline of a selected or highlighted card.
  static const double emphasisBorderWidth = 1.5;
}

/// How far system text scaling is followed. The system setting goes beyond
/// 3×, where a phone-sized layout stops being usable; twice the designed
/// size is the largest at which every screen still works on the smallest
/// phone (the layout test proves it), and it covers iOS's "Larger Text"
/// range up to its second-largest accessibility step.
abstract final class AppTextScale {
  static const double min = 0.9;
  static const double max = 2.0;
}
