import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/providers.dart';
import 'package:unspend/core/storage_keys.dart';
import 'package:unspend/features/app_blocker/data/datasources/screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/domain/entities/blocker_profile.dart';
import 'package:unspend/features/app_blocker/presentation/native_strings.dart';
import 'package:unspend/features/app_blocker/presentation/providers/profiles_provider.dart';

import '../support/app_harness.dart';

/// What is different on Android: access is an accessibility service that
/// the app explains before asking, the introduction has no "whose phone"
/// page, and the two iPhone-only settings are gone.
void main() {
  Future<AppHarness> android(
    WidgetTester tester, {
    List<BlockerProfile> profiles = const [],
    bool onboardingSeen = true,
    ScreenTimeAuthStatus auth = ScreenTimeAuthStatus.approved,
    ScreenTimeAuthStatus answer = ScreenTimeAuthStatus.approved,
    String locale = 'en',
  }) => pumpUnspend(
    tester,
    platform: AppPlatform.android,
    profiles: profiles,
    onboardingSeen: onboardingSeen,
    auth: auth,
    authAfterRequest: answer,
    locale: locale,
  );

  bool asked(AppHarness app) =>
      app.screenTime.calls.any((call) => call.startsWith('requestAuth'));

  group('introduction', () {
    Future<AppHarness> onPermissionPage(
      WidgetTester tester, {
      ScreenTimeAuthStatus answer = ScreenTimeAuthStatus.approved,
    }) async {
      final app = await android(
        tester,
        onboardingSeen: false,
        auth: ScreenTimeAuthStatus.notDetermined,
        answer: answer,
      );
      for (var page = 0; page < 3; page++) {
        expect(find.text(app.s.whoUsesTitle), findsNothing);
        await tester.tap(find.text(app.s.next));
        await tester.pumpAndSettle();
      }
      return app;
    }

    testWidgets('goes from the three pages straight to access', (tester) async {
      final app = await onPermissionPage(tester);

      expect(find.text(app.s.onboardingTitle4), findsOneWidget);
      expect(find.textContaining('accessibility service'), findsOneWidget);
      expect(find.text(app.s.authAllow), findsOneWidget);
    });

    testWidgets('explains the access before asking for it', (tester) async {
      final app = await onPermissionPage(tester);

      await tester.tap(find.text(app.s.authAllow));
      await tester.pumpAndSettle();

      expect(find.text(app.s.accessDisclosureTitle), findsOneWidget);
      expect(find.text(app.s.accessDisclosureBody), findsOneWidget);
      expect(asked(app), isFalse, reason: 'nothing happens before the yes');
    });

    testWidgets('a no leaves everything as it was', (tester) async {
      final app = await onPermissionPage(tester);
      await tester.tap(find.text(app.s.authAllow));
      await tester.pumpAndSettle();

      await tester.tap(find.text(app.s.cancel));
      await tester.pumpAndSettle();

      expect(asked(app), isFalse);
      expect(find.text(app.s.authAllow), findsOneWidget);
      expect(find.text(app.s.authDeniedHint), findsNothing);
    });

    testWidgets('a yes asks, and granted access leads on', (tester) async {
      final app = await onPermissionPage(tester);
      await tester.tap(find.text(app.s.authAllow));
      await tester.pumpAndSettle();

      await tester.tap(find.text(app.s.accessDisclosureAgree));
      await tester.pumpAndSettle();

      expect(asked(app), isTrue);
      expect(find.text(app.s.authGranted), findsOneWidget);

      await tester.tap(find.text(app.s.getStarted));
      await tester.pumpAndSettle();
      expect(find.text(app.s.profilesSectionTitle), findsOneWidget);
      expect(app.prefs.getBool(PrefKeys.onboardingSeen), isTrue);
    });

    testWidgets('access left switched off is explained', (tester) async {
      final app = await onPermissionPage(
        tester,
        answer: ScreenTimeAuthStatus.denied,
      );
      await tester.tap(find.text(app.s.authAllow));
      await tester.pumpAndSettle();
      await tester.tap(find.text(app.s.accessDisclosureAgree));
      await tester.pumpAndSettle();

      expect(find.text(app.s.authDeniedHint), findsOneWidget);
      expect(find.textContaining('Accessibility'), findsWidgets);
    });
  });

  group('dashboard banner', () {
    testWidgets('offers one way to allow access, through the explanation', (
      tester,
    ) async {
      final app = await android(tester, auth: ScreenTimeAuthStatus.denied);

      expect(find.text(app.s.authBannerTitle), findsOneWidget);
      expect(find.text(app.s.openSettings), findsNothing);

      await app.tap(find.text(app.s.authAllow));
      expect(find.text(app.s.accessDisclosureTitle), findsOneWidget);
      expect(asked(app), isFalse);
    });

    testWidgets('goes away once access is switched on', (tester) async {
      final app = await android(
        tester,
        auth: ScreenTimeAuthStatus.notDetermined,
      );
      await app.tap(find.text(app.s.authAllow));

      await tester.tap(find.text(app.s.accessDisclosureAgree));
      await tester.pumpAndSettle();

      expect(asked(app), isTrue);
      expect(find.text(app.s.authBannerTitle), findsNothing);
    });

    testWidgets('skips the explanation when access is on by now', (
      tester,
    ) async {
      final app = await android(tester, auth: ScreenTimeAuthStatus.denied);
      // Switched on in the system settings while the app was open.
      app.screenTime.authStatus = ScreenTimeAuthStatus.approved;

      await app.tap(find.text(app.s.authAllow));

      expect(find.text(app.s.accessDisclosureTitle), findsNothing);
      expect(find.text(app.s.authBannerTitle), findsNothing);
    });
  });

  group('profiles', () {
    testWidgets('apps can be picked without access', (tester) async {
      final app = await android(
        tester,
        profiles: sampleProfiles().where((p) => !p.isActive).toList(),
        auth: ScreenTimeAuthStatus.notDetermined,
      );
      final profile = app.profiles.firstWhere((p) => !p.isActive);
      app.screenTime.pickCount = 7;

      await app.container
          .read(profilesProvider.notifier)
          .pickAppsForProfile(profile.id, labels: appPickerLabels(app.s));
      await tester.pumpAndSettle();

      expect(asked(app), isFalse);
      expect(app.screenTime.calls, contains('pickApps:${profile.id}'));
      expect(app.profile(profile.id).appCount, 7);
    });
  });

  group('settings', () {
    testWidgets('has no iPhone-only entries', (tester) async {
      final app = await android(tester);
      await tester.tap(find.byTooltip(app.s.settings));
      await tester.pumpAndSettle();

      expect(find.text(app.s.changePin), findsOneWidget);
      expect(find.text(app.s.languageLabel), findsOneWidget);
      expect(find.text(app.s.whoUsesLabel), findsNothing);
      expect(find.text(app.s.uninstallProtection), findsNothing);
    });

    testWidgets('diagnostics name Android', (tester) async {
      final app = await android(tester);
      await tester.tap(find.byTooltip(app.s.settings));
      await tester.pumpAndSettle();
      await app.longPress(find.textContaining('Unspend 1.0.0'));

      expect(find.textContaining('Android '), findsOneWidget);
      expect(find.textContaining('iOS '), findsNothing);
    });
  });

  group('wording', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    // Names of the iPhone's way of blocking, in every language.
    final appleTerms = RegExp(
      'iPhone|iOS|Apple|Screen Time|Bildschirmzeit|Tiempo de uso|'
      'Temps d.écran|uporabe zaslona|FamilyControls',
    );

    /// The texts that are shown on Android.
    List<String> shown(S s) => [
      s.privacyPolicyBody,
      s.onboardingBody1,
      s.onboardingBody2,
      s.onboardingBody3,
      s.onboardingTitle4,
      s.onboardingBody4,
      s.authBannerTitle,
      s.authBannerBody,
      s.authDeniedHint,
      s.errorNotAuthorized,
      s.errorUnavailable,
      s.accessDisclosureTitle,
      s.accessDisclosureBody,
      s.accessDisclosureAgree,
    ];

    for (final locale in S.supportedLocales) {
      test('$locale: nothing shown on Android names the iPhone', () async {
        S.android = true;
        addTearDown(() => S.android = false);
        await S.setLocale(locale);

        for (final text in shown(S.current)) {
          expect(text, isNotEmpty);
          expect(appleTerms.hasMatch(text), isFalse, reason: text);
        }
      });

      test('$locale: the iPhone wording is untouched', () async {
        S.android = false;
        await S.setLocale(locale);

        expect(appleTerms.hasMatch(S.current.authBannerTitle), isTrue);
        expect(appleTerms.hasMatch(S.current.privacyPolicyBody), isTrue);
        expect(S.langCode, locale);
      });
    }

    test('the language is recognised on Android too', () async {
      S.android = true;
      addTearDown(() => S.android = false);
      await S.setLocale('hr');

      expect(S.langCode, 'hr');
    });
  });
}
