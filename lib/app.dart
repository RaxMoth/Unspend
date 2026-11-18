import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unspend/config/router.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/features/app_blocker/presentation/widgets/app_lifecycle_host.dart';
import 'package:unspend/shared/providers/locale_provider.dart';
import 'package:unspend/shared/providers/theme_mode_provider.dart';

/// The app: theme, language, routes.
///
/// Four themes are registered — light and dark, each also for the system's
/// Increase Contrast setting — and Flutter picks the one that matches the
/// user's choices. Text follows the system text size within the limits of
/// [AppTextScale].
class UnspendApp extends ConsumerWidget {
  const UnspendApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching the locale rebuilds the whole tree on a language switch.
    final langCode = ref.watch(localeProvider);
    return MaterialApp.router(
      title: 'Unspend',
      // The corner banner of debug builds would end up in screenshots.
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      highContrastTheme: AppTheme.lightHighContrast,
      highContrastDarkTheme: AppTheme.darkHighContrast,
      themeMode: ref.watch(themeModeProvider),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final dark = Theme.of(context).brightness == Brightness.dark;
        final onBars = dark ? Brightness.light : Brightness.dark;
        // The status and navigation bars take the app's background, with
        // icons that stand out on it.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: onBars,
            statusBarBrightness: Theme.of(context).brightness,
            systemNavigationBarColor: context.colors.background,
            systemNavigationBarIconBrightness: onBars,
          ),
          child: MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(
                minScaleFactor: AppTextScale.min,
                maxScaleFactor: AppTextScale.max,
              ),
            ),
            child: AppLifecycleHost(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
      locale: Locale(langCode),
      supportedLocales: [for (final code in S.supportedLocales) Locale(code)],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}
