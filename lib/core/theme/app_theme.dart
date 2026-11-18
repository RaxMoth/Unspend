import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_sizes.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds the Material theme from the design tokens, so Flutter's own
/// widgets (buttons, fields, dialogs, sheets, snack bars) look like the
/// rest of the app without per-widget styling.
abstract final class AppTheme {
  static final light = _build(AppColors.light);
  static final dark = _build(AppColors.dark);
  static final lightHighContrast = _build(AppColors.lightHighContrast);
  static final darkHighContrast = _build(AppColors.darkHighContrast);

  static ThemeData _build(AppColors colors) {
    final text = AppTextStyles.of(colors);
    final accentText = colors.accentText;
    final fieldBorder = OutlineInputBorder(
      borderRadius: AppRadius.control,
      borderSide: BorderSide(color: colors.border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      extensions: [colors, text],
      scaffoldBackgroundColor: colors.background,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: ColorScheme(
        brightness: colors.brightness,
        primary: colors.accent,
        onPrimary: colors.onAccentFill,
        secondary: colors.accent,
        onSecondary: colors.onAccentFill,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        onSurfaceVariant: colors.textSecondary,
        error: accentText,
        onError: colors.onAccentFill,
        outline: colors.border,
      ),
      textTheme: TextTheme(
        displaySmall: text.hero,
        headlineSmall: text.screenTitle,
        titleLarge: text.title,
        titleMedium: text.heading,
        titleSmall: text.subheading,
        bodyLarge: text.bodyLarge,
        bodyMedium: text.body,
        bodySmall: text.bodySmall.tone(colors.textSecondary),
        labelLarge: text.label,
        labelSmall: text.caption,
      ),
      iconTheme: IconThemeData(
        color: colors.textSecondary,
        size: AppSizes.iconLg,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      dividerTheme: DividerThemeData(color: colors.border, thickness: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accent,
        linearTrackColor: colors.border,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.background,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: colors.accent),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: accentText),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: accentText, width: 2),
        ),
        labelStyle: text.bodySmall.tone(colors.textSecondary),
        hintStyle: text.bodyLarge.tone(colors.textSecondary),
        errorStyle: text.caption.tone(accentText),
        errorMaxLines: 3,
        contentPadding: AppInsets.field,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accentFill,
          foregroundColor: colors.onAccentFill,
          disabledBackgroundColor: colors.border,
          disabledForegroundColor: colors.textSecondary,
          minimumSize: const Size.fromHeight(AppSizes.tapTarget),
          padding: AppInsets.button,
          shape: AppRadius.controlShape,
          textStyle: text.subheading,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentText,
          minimumSize: const Size(AppSizes.tapTarget, AppSizes.tapTarget),
          shape: AppRadius.controlShape,
          textStyle: text.body.strong,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.textSecondary,
          minimumSize: const Size(AppSizes.tapTarget, AppSizes.tapTarget),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.accentFill,
        foregroundColor: colors.onAccentFill,
        shape: AppRadius.cardShape,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: colors.background,
        selectedTileColor: colors.background,
        iconColor: colors.textSecondary,
        textColor: colors.textPrimary,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.caption.tone(colors.textSecondary),
        shape: AppRadius.controlShape,
        minTileHeight: AppSizes.tapTarget,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: AppRadius.sheetShape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: colors.border),
        ),
        titleTextStyle: text.heading,
        contentTextStyle: text.body.tone(colors.textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surface,
        contentTextStyle: text.body,
        actionTextColor: accentText,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.control,
          side: BorderSide(color: colors.border),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.textPrimary,
          borderRadius: AppRadius.chip,
        ),
        textStyle: text.caption.tone(colors.background),
      ),
    );
  }
}
