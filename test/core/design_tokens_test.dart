import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unspend/core/theme/design_tokens.dart';
import 'package:unspend/features/app_blocker/domain/entities/blocker_profile.dart';

void main() {
  tearDown(() => updateTokenBrightness(Brightness.dark));

  test('contrast ratio follows WCAG', () {
    expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(contrastRatio(Colors.white, Colors.black), closeTo(21, 0.01));
    expect(contrastRatio(kAccent, kAccent), 1);
  });

  test('white text on the accent fill is readable', () {
    expect(
      contrastRatio(Colors.white, kAccentFill),
      greaterThanOrEqualTo(kMinTextContrast),
    );
  });

  for (final brightness in Brightness.values) {
    group('${brightness.name} theme', () {
      setUp(() => updateTokenBrightness(brightness));

      test('primary and secondary text are readable on every surface', () {
        for (final surface in [kBg, kSurface]) {
          expect(
            contrastRatio(kTextPrimary, surface),
            greaterThanOrEqualTo(kMinTextContrast),
          );
          expect(
            contrastRatio(kTextSecondary, surface),
            greaterThanOrEqualTo(kMinTextContrast),
          );
        }
      });

      test('accent and success text are readable on every surface', () {
        for (final surface in [kBg, kSurface]) {
          for (final color in [kAccentText, kSuccessText]) {
            expect(
              contrastRatio(color, surface),
              greaterThanOrEqualTo(kMinTextContrast),
            );
          }
        }
      });

      for (final option in ProfileColor.palette) {
        test('${option.name} is readable as text, also on its own tint', () {
          final text = kReadable(option.color);
          final tinted = Color.alphaBlend(
            option.color.withValues(alpha: 0.15),
            kSurface,
          );
          for (final surface in [kBg, kSurface, tinted]) {
            expect(
              contrastRatio(text, surface),
              greaterThanOrEqualTo(kMinTextContrast),
              reason: '${option.name} text on $surface',
            );
          }
        });
      }
    });
  }

  for (final option in ProfileColor.palette) {
    test('a button filled with ${option.name} has readable text', () {
      final filled = kFilled(option.color);

      expect(
        contrastRatio(filled.onFill, filled.fill),
        greaterThanOrEqualTo(kMinTextContrast),
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

  test('a colour that is already readable is left alone', () {
    expect(readableOn(Colors.white, Colors.black), Colors.white);
    expect(readableOn(Colors.black, Colors.white), Colors.black);
  });
}
