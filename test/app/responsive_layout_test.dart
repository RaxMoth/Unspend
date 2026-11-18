import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unspend/config/router.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/providers.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/features/app_blocker/data/datasources/screen_time_datasource.dart';

import '../support/app_harness.dart';

/// Every screen, sheet and dialog, on the smallest and largest iPhones in
/// both orientations, at default and at the largest supported text size, in
/// all five languages. A scene fails when Flutter reports a layout problem
/// (overflow, unbounded size, …) in any combination.
///
/// The system text scale is set to 3×; the app caps it at
/// [AppTextScale.max], so this also proves the cap.
///
/// The check is stricter than a real device: the test font's glyphs are a
/// full em wide, about twice the width of the system font. A row that fits
/// here has room to spare on screen; one that overflows here is one long
/// translation away from overflowing for real.
const _textScales = [1.0, 3.0];

typedef _Scene = Future<void> Function(WidgetTester tester, AppHarness app);

/// The error's first line plus the widgets Flutter blames for it.
String _describe(FlutterErrorDetails details) {
  final summary = details.exceptionAsString().split('\n').first;
  final context = (details.informationCollector?.call() ?? const [])
      .map((node) => node.toStringDeep())
      .join(' ');
  final creator = RegExp(r'debugCreator: ([^\n]*)').firstMatch(context)?[1];
  if (creator == null) return summary;
  return '$summary In: ${creator.split(' ← ').take(8).join(' ← ')}';
}

/// Flings the scroll view in front (a sheet's, if one is open) to its end,
/// so content below the fold is laid out too.
Future<void> _scrollThrough(WidgetTester tester, AppHarness app) async {
  final scrollable = app.frontScrollable;
  if (scrollable.evaluate().isEmpty) return;
  await tester.fling(
    scrollable,
    const Offset(0, -3000),
    6000,
    warnIfMissed: false,
  );
  await tester.pumpAndSettle();
}

void _matrix(
  String scene, {
  bool onboardingSeen = true,
  bool withProfiles = true,
  ScreenTimeAuthStatus auth = ScreenTimeAuthStatus.approved,
  bool isChildAccount = true,
  String? pin,
  AppPlatform platform = AppPlatform.ios,
  required _Scene run,
}) {
  testWidgets(scene, (tester) async {
    final failures = <String>[];
    // Collect layout errors instead of letting the first one end the test,
    // so one run reports every broken combination.
    final problems = <FlutterErrorDetails>[];
    final reportError = FlutterError.onError;
    FlutterError.onError = problems.add;
    try {
      for (final device in devices) {
        for (final textScale in _textScales) {
          for (final locale in S.supportedLocales) {
            problems.clear();
            final where = '$device, text ×$textScale, $locale';
            final app = await pumpUnspend(
              tester,
              device: device,
              textScale: textScale,
              locale: locale,
              onboardingSeen: onboardingSeen,
              profiles: withProfiles ? sampleProfiles() : const [],
              auth: auth,
              authAfterRequest: auth,
              isChildAccount: isChildAccount,
              pin: pin,
              platform: platform,
              cooldown: const Duration(seconds: 300),
            );
            try {
              if (problems.isEmpty) await run(tester, app);
            } catch (error) {
              failures.add('$where: the scene could not be reached: $error');
            }
            if (problems.isNotEmpty) {
              failures.add('$where: ${_describe(problems.first)}');
            }
            await app.dispose();
          }
        }
      }
    } finally {
      FlutterError.onError = reportError;
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}

void main() {
  _matrix(
    'onboarding, all four pages',
    onboardingSeen: false,
    withProfiles: false,
    auth: ScreenTimeAuthStatus.notDetermined,
    run: (tester, app) async {
      for (var page = 0; page < 4; page++) {
        await _scrollThrough(tester, app);
        await app.tap(find.text(app.s.next));
      }
      await _scrollThrough(tester, app);
    },
  );

  _matrix(
    'onboarding, access refused',
    onboardingSeen: false,
    withProfiles: false,
    auth: ScreenTimeAuthStatus.denied,
    run: (tester, app) async {
      for (var page = 0; page < 4; page++) {
        await app.tap(find.text(app.s.next));
      }
      await app.tap(find.text(app.s.authAllow));
      await _scrollThrough(tester, app);
    },
  );

  _matrix(
    'onboarding, child mode on a phone that is not a child\'s',
    onboardingSeen: false,
    withProfiles: false,
    auth: ScreenTimeAuthStatus.notDetermined,
    isChildAccount: false,
    run: (tester, app) async {
      for (var page = 0; page < 3; page++) {
        await app.tap(find.text(app.s.next));
      }
      await app.tap(find.bySemanticsLabel(RegExp('^${app.s.modeChildTitle}')));
      await app.tap(find.text(app.s.next));
      await app.tap(find.text(app.s.authAllow));
      await _scrollThrough(tester, app);
    },
  );

  // Android has its own wording wherever access is mentioned, one page
  // less in the introduction and a dialog before access is asked for.
  _matrix(
    'Android: introduction',
    platform: AppPlatform.android,
    onboardingSeen: false,
    withProfiles: false,
    auth: ScreenTimeAuthStatus.notDetermined,
    run: (tester, app) async {
      for (var page = 0; page < 3; page++) {
        await _scrollThrough(tester, app);
        await app.tap(find.text(app.s.next));
      }
      expect(find.text(app.s.onboardingTitle4), findsOneWidget);
      await _scrollThrough(tester, app);
    },
  );

  _matrix(
    'Android: what the access is used for',
    platform: AppPlatform.android,
    auth: ScreenTimeAuthStatus.denied,
    run: (tester, app) async {
      await app.tap(find.text(app.s.authAllow));
      expect(find.text(app.s.accessDisclosureTitle), findsOneWidget);
      await _scrollThrough(tester, app);
    },
  );

  _matrix(
    'Android: settings and privacy policy',
    platform: AppPlatform.android,
    run: (tester, app) async {
      await app.tap(find.byTooltip(app.s.settings));
      await _scrollThrough(tester, app);
      await app.tap(find.text(app.s.privacyPolicyTitle));
      await _scrollThrough(tester, app);
    },
  );

  _matrix(
    'dashboard without profiles',
    withProfiles: false,
    run: _scrollThrough,
  );

  _matrix('dashboard with profiles', run: _scrollThrough);

  _matrix(
    'dashboard with the Screen Time banner',
    auth: ScreenTimeAuthStatus.denied,
    run: _scrollThrough,
  );

  _matrix(
    'new profile sheet',
    run: (tester, app) => app.tap(find.byTooltip(app.s.newProfile)),
  );

  _matrix(
    'settings sheet',
    run: (tester, app) async {
      await app.tap(find.byTooltip(app.s.settings));
      await _scrollThrough(tester, app);
    },
  );

  _matrix(
    'diagnostics sheet',
    run: (tester, app) async {
      await app.tap(find.byTooltip(app.s.settings));
      await app.longPress(find.textContaining('Unspend 1.0.0'));
      expect(find.text('Diagnostics'), findsOneWidget);
      await _scrollThrough(tester, app);
    },
  );

  for (final entry in <String, String Function(S)>{
    'who uses this iPhone sheet': (s) => s.whoUsesLabel,
    'uninstall protection sheet': (s) => s.uninstallProtection,
    'theme sheet': (s) => s.themeLabel,
    'language sheet': (s) => s.languageLabel,
    'privacy policy sheet': (s) => s.privacyPolicyTitle,
    'delete all data dialog': (s) => s.deleteAllData,
  }.entries) {
    _matrix(
      entry.key,
      run: (tester, app) async {
        await app.tap(find.byTooltip(app.s.settings));
        await app.tap(find.text(entry.value(app.s)));
      },
    );
  }

  _matrix(
    'PIN setup dialog',
    run: (tester, app) async {
      await app.tap(find.byTooltip(app.s.settings));
      await app.tap(find.text(app.s.changePin));
      // A validation message makes the dialog as tall as it gets.
      await app.tap(find.text(app.s.savePin));
    },
  );

  _matrix(
    'unlock dialog, cooldown',
    run: (tester, app) async {
      await app.tap(find.bySemanticsLabel(RegExp(app.s.deactivateShield)));
    },
  );

  _matrix(
    'unlock dialog, PIN entry with an error',
    pin: '2468',
    run: (tester, app) async {
      await app.tap(find.byTooltip(app.s.settings));
      await app.tap(find.text(app.s.changePin));
      // The profile "social" is active, so the cooldown comes first.
      await app.elapse(const Duration(seconds: 300));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0000');
      await app.tap(find.text(app.s.continueLabel));
    },
  );

  _matrix(
    'profile screen, inactive with every rule on',
    run: (tester, app) async {
      await app.open(AppRoutes.profile('games'));
      for (final rule in [
        app.s.scheduleTitle,
        app.s.usageLimitTitle,
        app.s.taskModeTitle,
      ]) {
        await app.tap(find.bySemanticsLabel(RegExp('^$rule')));
      }
      await _scrollThrough(tester, app);
    },
  );

  _matrix(
    'profile screen, active',
    run: (tester, app) async {
      await app.open(AppRoutes.profile('social'));
      await _scrollThrough(tester, app);
    },
  );

  _matrix(
    'profile screen, delete dialog',
    run: (tester, app) async {
      await app.open(AppRoutes.profile('games'));
      await app.tap(find.byTooltip(app.s.deleteProfile));
    },
  );

  for (final keypad in [false, true]) {
    _matrix(
      'daily limit sheet, ${keypad ? 'keypad' : 'wheel'}',
      run: (tester, app) async {
        await app.open(AppRoutes.profile('news'));
        await app.tap(find.text(app.s.dailyLimit));
        if (keypad) await app.tap(find.text(app.s.pickerModeKeypad));
      },
    );
  }

  _matrix(
    'time picker',
    run: (tester, app) async {
      await app.open(AppRoutes.profile('games'));
      await app.tap(find.bySemanticsLabel(RegExp('^${app.s.scheduleTitle}')));
      await app.tap(find.bySemanticsLabel(RegExp(app.s.scheduleStart)));
    },
  );

  _matrix('page not found', run: (tester, app) => app.open('/no/such/page'));
}
