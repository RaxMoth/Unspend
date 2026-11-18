import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/features/app_blocker/domain/entities/blocker_profile.dart';

/// The design system's promises: every palette keeps text readable, every
/// profile colour can be used as text and as a button, and the Material
/// theme carries the tokens.
void main() {
  const palettes = {
    'light': AppColors.light,
    'dark': AppColors.dark,
    'light, increased contrast': AppColors.lightHighContrast,
    'dark, increased contrast': AppColors.darkHighContrast,
  };

  test('contrast ratio follows WCAG', () {
    expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(contrastRatio(Colors.white, Colors.black), closeTo(21, 0.01));
    expect(contrastRatio(Colors.red, Colors.red), 1);
  });

  test('a colour that is already readable is left alone', () {
    expect(readableOn(Colors.white, Colors.black), Colors.white);
    expect(readableOn(Colors.black, Colors.white), Colors.black);
  });

  test('increased-contrast palettes aim for AAA', () {
    expect(AppColors.light.minTextContrast, kTextContrastAA);
    expect(AppColors.dark.minTextContrast, kTextContrastAA);
    expect(AppColors.lightHighContrast.minTextContrast, kTextContrastAAA);
    expect(AppColors.darkHighContrast.minTextContrast, kTextContrastAAA);
  });

  for (final MapEntry(key: name, value: colors) in palettes.entries) {
    group('$name palette', () {
      final target = colors.minTextContrast;

      test('primary and secondary text are readable on every surface', () {
        for (final surface in [colors.background, colors.surface]) {
          expect(
            contrastRatio(colors.textPrimary, surface),
            greaterThanOrEqualTo(target),
          );
          expect(
            contrastRatio(colors.textSecondary, surface),
            greaterThanOrEqualTo(target),
          );
        }
      });

      test('accent and success text are readable on every surface', () {
        for (final surface in [colors.background, colors.surface]) {
          for (final color in [colors.accentText, colors.successText]) {
            expect(contrastRatio(color, surface), greaterThanOrEqualTo(target));
          }
        }
      });

      test('text on the accent fill is readable', () {
        expect(
          contrastRatio(colors.onAccentFill, colors.accentFill),
          greaterThanOrEqualTo(target),
        );
      });

      test('outlines can be told apart from the surfaces they sit on', () {
        // In the regular palettes the hairline is deliberately quiet; with
        // increased contrast it has to reach the 3:1 asked of graphics.
        if (target < kTextContrastAAA) return;
        expect(
          contrastRatio(colors.border, colors.surface),
          greaterThanOrEqualTo(3),
        );
      });

      for (final option in ProfileColor.palette) {
        test('${option.name} is readable as text, also on its own tint', () {
          final text = colors.readable(option.color);
          final tinted = Color.alphaBlend(
            option.color.withValues(alpha: AppOpacity.tint),
            colors.surface,
          );
          for (final surface in [colors.background, colors.surface, tinted]) {
            expect(
              contrastRatio(text, surface),
              greaterThanOrEqualTo(kTextContrastAA),
              reason: '${option.name} text on $surface',
            );
          }
        });
      }
    });
  }

  for (final option in ProfileColor.palette) {
    test('a button filled with ${option.name} has readable text', () {
      final filled = AppColors.light.filled(option.color);

      expect(
        contrastRatio(filled.onFill, filled.fill),
        greaterThanOrEqualTo(kTextContrastAA),
      );
      // The fill stays recognisably the profile's colour.
      expect(
        (HSLColor.fromColor(filled.fill).hue -
                HSLColor.fromColor(option.color).hue)
            .abs(),
        lessThan(2),
      );
    });
  }

  group('theme extensions', () {
    test('cross-fading palettes ends on the target palette', () {
      final mixed = AppColors.light.lerp(AppColors.dark, 1);

      expect(mixed.background, AppColors.dark.background);
      expect(mixed.textPrimary, AppColors.dark.textPrimary);
      expect(mixed.brightness, Brightness.dark);
      expect(
        AppColors.light.lerp(AppColors.dark, 0).background,
        AppColors.light.background,
      );
      expect(AppColors.light.lerp(null, 0.5), AppColors.light);
    });

    test('copyWith changes only what is passed', () {
      final changed = AppColors.dark.copyWith(accent: Colors.blue);

      expect(changed.accent, Colors.blue);
      expect(changed.surface, AppColors.dark.surface);
    });

    test('the type scale takes its colour from the palette', () {
      final text = AppTextStyles.of(AppColors.light);

      expect(text.body.color, AppColors.light.textPrimary);
      expect(text.display.fontSize, greaterThan(text.hero.fontSize!));
      expect(text.hero.fontSize, greaterThan(text.title.fontSize!));
      expect(text.title.fontSize, greaterThan(text.body.fontSize!));
      expect(text.body.fontSize, greaterThan(text.micro.fontSize!));
      expect(text.body.strong.fontWeight, FontWeight.w600);
      expect(text.body.tone(Colors.red).color, Colors.red);
    });

    test('every theme carries its palette and type scale', () {
      final themes = {
        AppTheme.light: AppColors.light,
        AppTheme.dark: AppColors.dark,
        AppTheme.lightHighContrast: AppColors.lightHighContrast,
        AppTheme.darkHighContrast: AppColors.darkHighContrast,
      };
      for (final MapEntry(key: theme, value: colors) in themes.entries) {
        expect(theme.extension<AppColors>(), colors);
        expect(theme.extension<AppTextStyles>(), isNotNull);
        expect(theme.scaffoldBackgroundColor, colors.background);
        expect(theme.brightness, colors.brightness);
      }
    });

    testWidgets('without the app theme the tokens fall back to defaults', (
      tester,
    ) async {
      late AppColors colors;
      late AppTextStyles text;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: Builder(
            builder: (context) {
              colors = context.colors;
              text = context.text;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(colors, AppColors.light);
      expect(text.body.color, AppColors.light.textPrimary);
    });

    testWidgets('motion stops when the system asks to reduce it', (
      tester,
    ) async {
      late Duration normal;
      late Duration reduced;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              normal = context.motion(AppDurations.medium);
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: Builder(
                  builder: (context) {
                    reduced = context.motion(AppDurations.medium);
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(normal, AppDurations.medium);
      expect(reduced, Duration.zero);
    });
  });

  test('the spacing scale is a 4-point grid above the smallest step', () {
    for (final step in [
      AppSpacing.xs,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.xl,
      AppSpacing.xxl,
      AppSpacing.xxxl,
      AppSpacing.huge,
    ]) {
      expect(step % 4, 0, reason: '$step');
    }
    expect(AppSizes.tapTarget, greaterThanOrEqualTo(44));
  });
}
