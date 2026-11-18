import 'package:flutter/material.dart';

/// How strongly a colour is laid over a surface. Used with
/// `color.withValues(alpha: AppOpacity.x)` so tints look the same everywhere.
abstract final class AppOpacity {
  /// A barely-there wash behind the content of a highlighted card.
  static const double wash = 0.08;

  /// Background of badges, chips and icon tiles in a colour.
  static const double tint = 0.15;

  /// Outline of a highlighted card.
  static const double outline = 0.4;

  /// Content of a disabled or locked control.
  static const double disabled = 0.5;
}

/// Fill and content colour of a filled control (button, segment).
typedef FilledColors = ({Color fill, Color onFill});

/// Minimum contrast between text and its background (WCAG AA), and the
/// stricter target used when the system asks for increased contrast (AAA).
const double kTextContrastAA = 4.5;
const double kTextContrastAAA = 7;

/// WCAG contrast ratio between two colours, from 1 (none) to 21.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// [color], made lighter on a dark [background] or darker on a light one
/// until it reaches [minContrast] against it. The hue is kept, so the result
/// still reads as the same colour.
Color readableOn(
  Color color,
  Color background, {
  double minContrast = kTextContrastAA,
}) {
  final lighten = background.computeLuminance() < 0.5;
  var hsl = HSLColor.fromColor(color);
  var result = color;
  for (var step = 0; step < 50; step++) {
    if (contrastRatio(result, background) >= minContrast) break;
    hsl = hsl.withLightness(
      (hsl.lightness + (lighten ? 0.02 : -0.02)).clamp(0.0, 1.0),
    );
    result = hsl.toColor();
  }
  return result;
}

/// The app's colours for one theme. Read them with `context.colors`.
///
/// There are four palettes: light and dark, each also in an
/// increased-contrast variant that iOS selects through Accessibility →
/// Increase Contrast. Widgets never pick a palette themselves.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.accentFill,
    required this.accentContainer,
    required this.success,
    required this.activeGradient,
    required this.contrastSurface,
    this.minTextContrast = kTextContrastAA,
  });

  final Brightness brightness;

  /// Behind everything.
  final Color background;

  /// Cards, sheets and dialogs.
  final Color surface;

  /// Hairlines around and between surfaces; also the track of switches and
  /// progress bars.
  final Color border;

  final Color textPrimary;
  final Color textSecondary;

  /// The brand red, for icons, borders and other graphics. For text use
  /// [accentText]; behind white text use [accentFill].
  final Color accent;

  /// The brand red as the background of a button with [onAccentFill] text.
  final Color accentFill;

  /// A soft red surface, behind the shield icon of an active summary.
  final Color accentContainer;

  /// Completed / not blocking, as a graphic. For text use [successText].
  final Color success;

  /// Background of the summary card while something is active.
  final List<Color> activeGradient;

  /// The surface on which coloured text has the least contrast in this
  /// theme (a tinted card). [readable] measures against it.
  final Color contrastSurface;

  /// Contrast that coloured text has to reach.
  final double minTextContrast;

  /// Text and icons on [accentFill].
  Color get onAccentFill => Colors.white;

  bool get isDark => brightness == Brightness.dark;

  /// The brand red for text.
  Color get accentText => readable(accent);

  /// The success green for text.
  Color get successText => readable(success);

  static final _readable = <(int, int, double), Color>{};
  static final _filled = <int, FilledColors>{};

  /// [color] adjusted so text or small icons in it are readable on this
  /// theme's surfaces. Profiles come in nine colours; several of them (amber
  /// on white, indigo on black) are not readable as they are.
  Color readable(Color color) {
    if (_readable.length > 256) _readable.clear();
    return _readable.putIfAbsent((
      color.toARGB32(),
      contrastSurface.toARGB32(),
      minTextContrast,
    ), () => readableOn(color, contrastSurface, minContrast: minTextContrast));
  }

  /// Colours for a filled control in [color]. Dark enough colours get white
  /// text, with the fill darkened slightly if needed; bright ones (orange,
  /// amber) keep their fill and get black text.
  FilledColors filled(Color color) => _filled.putIfAbsent(
    color.toARGB32(),
    () => contrastRatio(Colors.white, color) >= 3
        ? (fill: readableOn(color, Colors.white), onFill: Colors.white)
        : (fill: color, onFill: Colors.black),
  );

  // ── Palettes ───────────────────────────────────────────────────────────

  static const _brandRed = Color(0xFFE53935);
  static const _brandRedFill = Color(0xFFE32723);
  static const _green = Color(0xFF43A047);

  static const dark = AppColors(
    brightness: Brightness.dark,
    background: Color(0xFF0D0D0D),
    surface: Color(0xFF1A1A1A),
    border: Color(0xFF2A2A2A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9E9E9E),
    accent: _brandRed,
    accentFill: _brandRedFill,
    accentContainer: Color(0xFF8B1A1A),
    success: _green,
    activeGradient: [Color(0xFF2B0D0D), Color(0xFF1A0808)],
    contrastSurface: Color(0xFF2A2A2A),
  );

  static const light = AppColors(
    brightness: Brightness.light,
    background: Color(0xFFF5F5F5),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE0E0E0),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF666666),
    accent: _brandRed,
    accentFill: _brandRedFill,
    accentContainer: Color(0xFFFFCDD2),
    success: _green,
    activeGradient: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
    contrastSurface: Color(0xFFE0E0E0),
  );

  /// Dark, with stronger outlines and secondary text.
  static const darkHighContrast = AppColors(
    brightness: Brightness.dark,
    background: Color(0xFF000000),
    surface: Color(0xFF161616),
    border: Color(0xFF6B6B6B),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFD0D0D0),
    accent: Color(0xFFFF6B66),
    accentFill: Color(0xFFA31515),
    accentContainer: Color(0xFF8B1A1A),
    success: Color(0xFF66BB6A),
    activeGradient: [Color(0xFF2B0D0D), Color(0xFF1A0808)],
    contrastSurface: Color(0xFF2A2A2A),
    minTextContrast: kTextContrastAAA,
  );

  /// Light, with stronger outlines and secondary text.
  static const lightHighContrast = AppColors(
    brightness: Brightness.light,
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFF7A7A7A),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF3D3D3D),
    accent: Color(0xFFC62828),
    accentFill: Color(0xFFA31515),
    accentContainer: Color(0xFFFFCDD2),
    success: Color(0xFF2E7D32),
    activeGradient: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
    contrastSurface: Color(0xFFE0E0E0),
    minTextContrast: kTextContrastAAA,
  );

  @override
  AppColors copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? accentFill,
    Color? accentContainer,
    Color? success,
    List<Color>? activeGradient,
    Color? contrastSurface,
    double? minTextContrast,
  }) => AppColors(
    brightness: brightness ?? this.brightness,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    border: border ?? this.border,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    accent: accent ?? this.accent,
    accentFill: accentFill ?? this.accentFill,
    accentContainer: accentContainer ?? this.accentContainer,
    success: success ?? this.success,
    activeGradient: activeGradient ?? this.activeGradient,
    contrastSurface: contrastSurface ?? this.contrastSurface,
    minTextContrast: minTextContrast ?? this.minTextContrast,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      border: mix(border, other.border),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      accent: mix(accent, other.accent),
      accentFill: mix(accentFill, other.accentFill),
      accentContainer: mix(accentContainer, other.accentContainer),
      success: mix(success, other.success),
      activeGradient: [
        for (var i = 0; i < activeGradient.length; i++)
          mix(activeGradient[i], other.activeGradient[i]),
      ],
      // Not interpolated: a half-way value would defeat the contrast target
      // and flood the cache during the cross-fade.
      contrastSurface: t < 0.5 ? contrastSurface : other.contrastSurface,
      minTextContrast: t < 0.5 ? minTextContrast : other.minTextContrast,
    );
  }
}
