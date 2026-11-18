import 'package:flutter/material.dart';

// ── Brightness-aware token resolver ────────────────────────────────────────
Brightness _brightness = Brightness.dark;

/// Called by the app whenever the resolved theme brightness changes, so the
/// getters below return the colours of the current theme.
void updateTokenBrightness(Brightness b) => _brightness = b;

bool get _isDark => _brightness == Brightness.dark;

// ── Surfaces and text ──────────────────────────────────────────────────────
Color get kBg => _isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5);
Color get kSurface =>
    _isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);
Color get kBorder =>
    _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
Color get kTextPrimary =>
    _isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1A1A1A);
Color get kTextSecondary =>
    _isDark ? const Color(0xFF9E9E9E) : const Color(0xFF666666);

// ── Brand colours ──────────────────────────────────────────────────────────
/// The brand red, for icons, borders and other graphics. For text use
/// [kAccentText]; behind white text use [kAccentFill].
const kAccent = Color(0xFFE53935);

/// The brand red as the background of a button with white text.
const kAccentFill = Color(0xFFE32723);

/// Success / completed state (task done, profile not blocking), as a graphic.
/// For text use [kSuccessText].
const kSuccess = Color(0xFF43A047);

Color get kAccentDark =>
    _isDark ? const Color(0xFF8B1A1A) : const Color(0xFFFFCDD2);

/// The brand red for text on the current theme's surfaces.
Color get kAccentText => kReadable(kAccent);

/// The success green for text on the current theme's surfaces.
Color get kSuccessText => kReadable(kSuccess);

// ── Gradient tokens ────────────────────────────────────────────────────────
List<Color> get kActiveGradient => _isDark
    ? const [Color(0xFF2B0D0D), Color(0xFF1A0808)]
    : const [Color(0xFFFFEBEE), Color(0xFFFFCDD2)];

// ── Radius tokens ──────────────────────────────────────────────────────────
const kRadius = 16.0;

// ── Readable colour variants ───────────────────────────────────────────────
//
// Profiles come in nine colours and the app has two themes. A colour that
// works as a swatch is often unreadable as text (amber on white) or behind
// white text (amber again). These helpers derive variants that meet the
// WCAG AA contrast of 4.5:1 while staying as close to the colour as possible.

/// Minimum contrast between text and its background (WCAG AA).
const kMinTextContrast = 4.5;

/// WCAG contrast ratio between two colours, from 1 (none) to 21.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

/// [color], made lighter on a dark [background] or darker on a light one
/// until it reaches [kMinTextContrast] against it.
Color readableOn(Color color, Color background) {
  final lighten = background.computeLuminance() < 0.5;
  var hsl = HSLColor.fromColor(color);
  var result = color;
  for (var step = 0; step < 50; step++) {
    if (contrastRatio(result, background) >= kMinTextContrast) break;
    hsl = hsl.withLightness(
      (hsl.lightness + (lighten ? 0.02 : -0.02)).clamp(0.0, 1.0),
    );
    result = hsl.toColor();
  }
  return result;
}

// Text in a profile colour also sits on tinted cards, which are a little
// lighter (dark theme) or darker (light theme) than the plain surface.
const _darkestLightSurface = Color(0xFFE0E0E0);
const _lightestDarkSurface = Color(0xFF2A2A2A);

final _readable = <(int, bool), Color>{};

/// [color] adjusted so that text or small icons in it are readable on the
/// current theme's surfaces.
Color kReadable(Color color) => _readable.putIfAbsent(
  (color.toARGB32(), _isDark),
  () =>
      readableOn(color, _isDark ? _lightestDarkSurface : _darkestLightSurface),
);

final _filled = <int, ({Color fill, Color onFill})>{};

/// Colours for a filled control in [color]: the fill and the text on it.
///
/// Dark enough colours get white text, with the fill darkened slightly if
/// needed; bright colours (orange, amber) keep their fill and get black text.
({Color fill, Color onFill}) kFilled(Color color) => _filled.putIfAbsent(
  color.toARGB32(),
  () => contrastRatio(Colors.white, color) >= 3
      ? (fill: readableOn(color, Colors.white), onFill: Colors.white)
      : (fill: color, onFill: Colors.black),
);
