/// The design system. Import this one file to get every token.
///
/// See `docs/DESIGN_SYSTEM.md` for how the pieces are meant to be used.
library;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

export 'app_colors.dart';
export 'app_haptics.dart';
export 'app_motion.dart';
export 'app_radius.dart';
export 'app_sizes.dart';
export 'app_spacing.dart';
export 'app_theme.dart';
export 'app_typography.dart';

extension AppThemeContext on BuildContext {
  /// The colours of the current theme (light or dark, normal or increased
  /// contrast).
  AppColors get colors {
    final theme = Theme.of(this);
    return theme.extension<AppColors>() ??
        (theme.brightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light);
  }

  /// The type scale in the current theme's primary text colour.
  AppTextStyles get text =>
      Theme.of(this).extension<AppTextStyles>() ?? AppTextStyles.of(colors);
}
