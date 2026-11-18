import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unspend/app.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/providers.dart';
import 'package:unspend/core/theme/theme.dart';

/// Starts the app. [overrides] replace infrastructure providers; the
/// development entrypoint (`main_dev.dart`) uses them to run without the
/// real Screen Time bridge.
Future<void> bootstrap({List<Override> overrides = const []}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await S.init();

  // An uncaught error is logged; it must not take the app down.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[Unhandled] $error\n$stack');
    return true;
  };
  if (kReleaseMode) {
    // A widget that fails to build shows a short notice instead of the
    // default grey box.
    ErrorWidget.builder = (details) => const _BrokenWidgetNotice();
  }

  // Loaded once up front so the rest of the app reads preferences
  // synchronously.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...overrides,
      ],
      child: const UnspendApp(),
    ),
  );
}

/// Shown in release builds in place of a widget that failed to build. It
/// may appear anywhere in the tree, so it relies on nothing above it.
class _BrokenWidgetNotice extends StatelessWidget {
  const _BrokenWidgetNotice();

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.dark;
    return Container(
      alignment: Alignment.center,
      padding: AppInsets.card,
      child: Text(
        S.current.errorTryAgain,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        style: AppTextStyles.of(colors).body.tone(colors.textSecondary),
      ),
    );
  }
}
