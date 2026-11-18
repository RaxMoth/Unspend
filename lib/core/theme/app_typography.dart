import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The type scale. Read it with `context.text`.
///
/// Every style carries the theme's primary text colour; use [TextStyleTone]
/// (`.tone(color)`) for secondary or coloured text. Sizes are in points
/// before the user's text-size setting is applied.
@immutable
class AppTextStyles extends ThemeExtension<AppTextStyles> {
  const AppTextStyles({
    required this.display,
    required this.numeral,
    required this.hero,
    required this.screenTitle,
    required this.title,
    required this.heading,
    required this.subheading,
    required this.label,
    required this.bodyLarge,
    required this.body,
    required this.bodySmall,
    required this.caption,
    required this.micro,
  });

  /// Derives the scale for a palette.
  factory AppTextStyles.of(AppColors colors) {
    TextStyle style(double size, FontWeight weight, {double? height}) =>
        TextStyle(
          color: colors.textPrimary,
          fontSize: size,
          fontWeight: weight,
          height: height,
        );
    return AppTextStyles(
      display: style(
        40,
        FontWeight.bold,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      numeral: style(32, FontWeight.bold),
      hero: style(26, FontWeight.bold),
      screenTitle: style(24, FontWeight.bold),
      title: style(20, FontWeight.bold),
      heading: style(18, FontWeight.w600),
      subheading: style(16, FontWeight.w600),
      label: style(15, FontWeight.w600),
      bodyLarge: style(16, FontWeight.normal),
      body: style(14, FontWeight.normal),
      bodySmall: style(13, FontWeight.normal),
      caption: style(12, FontWeight.normal),
      micro: style(11, FontWeight.normal),
    );
  }

  /// 40 bold, fixed-width digits — the cooldown countdown.
  final TextStyle display;

  /// 32 bold — numbers being entered.
  final TextStyle numeral;

  /// 26 bold — the headline of an onboarding page.
  final TextStyle hero;

  /// 24 bold — the name at the top of a screen.
  final TextStyle screenTitle;

  /// 20 bold — sheet and page titles.
  final TextStyle title;

  /// 18 semibold — section and dialog titles, card headlines.
  final TextStyle heading;

  /// 16 semibold — card titles, primary buttons.
  final TextStyle subheading;

  /// 15 semibold — row titles and secondary buttons.
  final TextStyle label;

  /// 16 — text the user types, list rows.
  final TextStyle bodyLarge;

  /// 14 — running text.
  final TextStyle body;

  /// 13 — descriptions under a title.
  final TextStyle bodySmall;

  /// 12 — hints, counters, badges.
  final TextStyle caption;

  /// 11 — labels inside small chips and tiles.
  final TextStyle micro;

  @override
  AppTextStyles copyWith() => this;

  @override
  AppTextStyles lerp(AppTextStyles? other, double t) {
    if (other == null) return this;
    TextStyle mix(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return AppTextStyles(
      display: mix(display, other.display),
      numeral: mix(numeral, other.numeral),
      hero: mix(hero, other.hero),
      screenTitle: mix(screenTitle, other.screenTitle),
      title: mix(title, other.title),
      heading: mix(heading, other.heading),
      subheading: mix(subheading, other.subheading),
      label: mix(label, other.label),
      bodyLarge: mix(bodyLarge, other.bodyLarge),
      body: mix(body, other.body),
      bodySmall: mix(bodySmall, other.bodySmall),
      caption: mix(caption, other.caption),
      micro: mix(micro, other.micro),
    );
  }
}

extension TextStyleTone on TextStyle {
  /// This style in another colour.
  TextStyle tone(Color color) => copyWith(color: color);

  /// This style, semibold.
  TextStyle get strong => copyWith(fontWeight: FontWeight.w600);

  /// This style with generous line spacing, for paragraphs.
  TextStyle get relaxed => copyWith(height: 1.6);
}
