import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/providers.dart';
import 'package:unspend/core/widgets/app_switch.dart';
import 'package:unspend/features/app_blocker/data/repositories/pin_repository.dart';
import 'package:unspend/features/app_blocker/presentation/native_strings.dart';
import 'package:unspend/features/app_blocker/presentation/providers/device_mode_provider.dart';
import 'package:unspend/features/app_blocker/presentation/providers/uninstall_protection_provider.dart';
import 'package:unspend/shared/providers/theme_mode_provider.dart';

import '../support/app_harness.dart';

void main() {
  /// Profiles with nothing active.
  List<dynamic> idleProfiles() =>
      sampleProfiles().where((p) => !p.isActive).toList();

  Future<void> openSetting(
    WidgetTester tester,
    AppHarness app,
    String title,
  ) async {
    await tester.tap(find.byTooltip(app.s.settings));
    await tester.pumpAndSettle();
    await app.tap(find.text(title));
  }

  Future<void> enterNewPin(
    WidgetTester tester,
    AppHarness app,
    String pin,
    String confirmation,
  ) async {
    await tester.enterText(find.byType(TextField).at(0), pin);
    await tester.enterText(find.byType(TextField).at(1), confirmation);
    await tester.tap(find.text(app.s.savePin));
    await tester.pumpAndSettle();
  }

  group('change PIN', () {
    testWidgets('without a PIN the new one is validated and saved', (
      tester,
    ) async {
      final app = await pumpUnspend(tester);
      await openSetting(tester, app, app.s.changePin);
      expect(find.text(app.s.setPinTitle), findsOneWidget);

      await enterNewPin(tester, app, '12', '12');
      expect(find.text(app.s.pinTooShort), findsOneWidget);

      await enterNewPin(tester, app, '1234', '4321');
      expect(find.text(app.s.pinsMismatch), findsOneWidget);
      expect(await app.pins.hasPin(), isFalse);

      await enterNewPin(tester, app, '1234', '1234');
      expect(find.text(app.s.pinSaved), findsOneWidget);
      expect(await app.pins.verify('1234'), isA<PinCorrect>());
    });

    testWidgets('the current PIN is required first', (tester) async {
      final app = await pumpUnspend(tester, pin: '2468');
      await openSetting(tester, app, app.s.changePin);

      expect(find.text(app.s.setPinTitle), findsNothing);
      expect(find.text(app.s.enterTrustedPersonPin), findsOneWidget);

      await tester.enterText(find.byType(TextField), '0000');
      await tester.tap(find.text(app.s.continueLabel));
      await tester.pumpAndSettle();
      expect(find.text(app.s.incorrectPin), findsOneWidget);

      await tester.enterText(find.byType(TextField), '2468');
      await tester.tap(find.text(app.s.continueLabel));
      await tester.pumpAndSettle();
      expect(find.text(app.s.setPinTitle), findsOneWidget);

      await enterNewPin(tester, app, '13579', '13579');
      expect(await app.pins.verify('13579'), isA<PinCorrect>());
      expect(await app.pins.verify('2468'), isA<PinWrong>());
    });

    testWidgets('while a profile is active the cooldown comes first', (
      tester,
    ) async {
      final app = await pumpUnspend(
        tester,
        profiles: sampleProfiles(),
        pin: '2468',
      );
      await openSetting(tester, app, app.s.changePin);

      expect(find.text('00:03'), findsOneWidget);
      expect(find.text(app.s.cooldownGeneric), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await app.elapse(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text(app.s.enterTrustedPersonPin), findsOneWidget);
    });

    testWidgets('cancelling keeps the old PIN', (tester) async {
      final app = await pumpUnspend(tester, pin: '2468');
      await openSetting(tester, app, app.s.changePin);
      await tester.enterText(find.byType(TextField), '2468');
      await tester.tap(find.text(app.s.continueLabel));
      await tester.pumpAndSettle();

      await tester.tap(find.text(app.s.cancel));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(await app.pins.verify('2468'), isA<PinCorrect>());
    });
  });

  group('delete all data', () {
    testWidgets('asks first; cancelling deletes nothing', (tester) async {
      final app = await pumpUnspend(tester, profiles: [...idleProfiles()]);
      await openSetting(tester, app, app.s.deleteAllData);
      expect(find.text(app.s.deleteAllDataWarning), findsOneWidget);

      await tester.tap(find.text(app.s.cancel));
      await tester.pumpAndSettle();

      expect(app.profiles, hasLength(2));
      expect(app.screenTime.calls, isNot(contains('resetAll')));
    });

    testWidgets('with nothing active it wipes everything and starts over', (
      tester,
    ) async {
      final app = await pumpUnspend(
        tester,
        profiles: [...idleProfiles()],
        pin: '2468',
      );
      await openSetting(tester, app, app.s.deleteAllData);

      await tester.tap(find.text(app.s.deleteAllDataConfirm));
      await tester.pumpAndSettle();

      expect(app.screenTime.calls, contains('resetAll'));
      expect(app.profiles, isEmpty);
      expect(await app.pins.hasPin(), isFalse);
      expect(app.prefs.getBool(kHasSeenOnboardingKey), isNull);
      expect(find.text(app.s.onboardingTitle1), findsOneWidget);
    });

    testWidgets('with an active profile it takes the cooldown and the PIN', (
      tester,
    ) async {
      final app = await pumpUnspend(
        tester,
        profiles: sampleProfiles(),
        pin: '2468',
      );
      await openSetting(tester, app, app.s.deleteAllData);
      await tester.tap(find.text(app.s.deleteAllDataConfirm));
      await tester.pump();
      await tester.pump();

      expect(find.text('00:03'), findsOneWidget);
      expect(app.profiles, hasLength(3), reason: 'nothing deleted yet');

      await app.elapse(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0000');
      await tester.tap(find.text(app.s.continueLabel));
      await tester.pumpAndSettle();
      expect(app.profiles, hasLength(3));
      expect(app.screenTime.isShielded('social'), isTrue);

      await tester.enterText(find.byType(TextField), '2468');
      await tester.tap(find.text(app.s.continueLabel));
      await tester.pumpAndSettle();
      expect(app.profiles, isEmpty);
      expect(app.screenTime.isShielded('social'), isFalse);
      expect(find.text(app.s.onboardingTitle1), findsOneWidget);
    });

    testWidgets('backing out of the gate deletes nothing', (tester) async {
      final app = await pumpUnspend(tester, profiles: sampleProfiles());
      await openSetting(tester, app, app.s.deleteAllData);
      await tester.tap(find.text(app.s.deleteAllDataConfirm));
      // The countdown keeps ticking, so instead of settling wait a fixed
      // moment for the confirmation to close and the gate to open.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text(app.s.cooldownGeneric), findsOneWidget);

      await tester.tap(find.text(app.s.cancel));
      await tester.pumpAndSettle();

      expect(app.profiles, hasLength(3));
      expect(app.screenTime.isShielded('social'), isTrue);
    });
  });

  group('who uses this iPhone', () {
    Future<void> choose(WidgetTester tester, AppHarness app, String title) =>
        app.tap(find.bySemanticsLabel(RegExp('^$title')));

    testWidgets('the current choice is shown', (tester) async {
      final app = await pumpUnspend(tester, mode: DeviceMode.child);
      await tester.tap(find.byTooltip(app.s.settings));
      await tester.pumpAndSettle();

      expect(find.text(app.s.modeChildShort), findsOneWidget);
    });

    testWidgets('switching to a child\'s iPhone asks a parent to approve', (
      tester,
    ) async {
      final app = await pumpUnspend(tester);
      await openSetting(tester, app, app.s.whoUsesLabel);
      expect(find.text(app.s.whoUsesChangeInfo), findsOneWidget);

      await choose(tester, app, app.s.modeChildTitle);

      expect(app.screenTime.calls, [
        'revokeAuthorization',
        'requestAuthorization:child',
      ]);
      expect(app.container.read(deviceModeProvider), DeviceMode.child);
      expect(find.text(app.s.authGranted), findsOneWidget);
      expect(find.text(app.s.authBannerTitle), findsNothing);
    });

    testWidgets('tapping the current choice changes nothing', (tester) async {
      final app = await pumpUnspend(tester);
      await openSetting(tester, app, app.s.whoUsesLabel);

      await choose(tester, app, app.s.modePersonalTitle);

      expect(app.screenTime.calls, isEmpty);
    });

    testWidgets(
      'a phone that is not a child\'s explains and shows the banner',
      (tester) async {
        final app = await pumpUnspend(tester, isChildAccount: false);
        await openSetting(tester, app, app.s.whoUsesLabel);

        await choose(tester, app, app.s.modeChildTitle);

        expect(find.text(app.s.authNotChildAccount), findsOneWidget);
        expect(find.text(app.s.authBannerTitle), findsOneWidget);
      },
    );

    testWidgets('it cannot be changed while a profile is active', (
      tester,
    ) async {
      final app = await pumpUnspend(tester, profiles: sampleProfiles());
      await openSetting(tester, app, app.s.whoUsesLabel);

      await choose(tester, app, app.s.modeChildTitle);

      expect(find.text(app.s.deactivateAllFirst), findsOneWidget);
      expect(app.screenTime.calls, isEmpty);
      expect(app.container.read(deviceModeProvider), DeviceMode.personal);
      expect(app.screenTime.isShielded('social'), isTrue);
    });

    testWidgets('with a PIN set, the PIN is asked for first', (tester) async {
      final app = await pumpUnspend(tester, pin: '2468');
      await openSetting(tester, app, app.s.whoUsesLabel);
      await choose(tester, app, app.s.modeChildTitle);

      expect(find.text(app.s.enterTrustedPersonPin), findsOneWidget);
      expect(app.screenTime.calls, isEmpty);

      await tester.enterText(find.byType(TextField), '2468');
      await tester.tap(find.text(app.s.continueLabel));
      await tester.pumpAndSettle();

      expect(app.container.read(deviceModeProvider), DeviceMode.child);
    });
  });

  group('uninstall protection', () {
    // The sheet's title carries the same label; the switch is the target.
    Finder protectionSwitch(AppHarness app) => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(AppSwitch),
    );

    testWidgets('is on by default and explained', (tester) async {
      final app = await pumpUnspend(tester);
      await tester.tap(find.byTooltip(app.s.settings));
      await tester.pumpAndSettle();
      expect(find.text(app.s.stateOn), findsOneWidget);

      await app.tap(find.text(app.s.uninstallProtection));
      expect(find.text(app.s.uninstallProtectionBody), findsOneWidget);
    });

    testWidgets('with nothing to protect it switches off and on freely', (
      tester,
    ) async {
      final app = await pumpUnspend(tester);
      await openSetting(tester, app, app.s.uninstallProtection);

      await tester.tap(protectionSwitch(app));
      await tester.pumpAndSettle();
      expect(app.container.read(uninstallProtectionProvider), isFalse);
      expect(app.screenTime.calls, ['setRemovalLockEnabled:false']);
      expect(find.text(app.s.stateOff), findsOneWidget);

      await tester.tap(protectionSwitch(app));
      await tester.pumpAndSettle();
      expect(app.container.read(uninstallProtectionProvider), isTrue);
    });

    testWidgets('switching it off needs the PIN when one is set', (
      tester,
    ) async {
      final app = await pumpUnspend(tester, pin: '2468');
      await openSetting(tester, app, app.s.uninstallProtection);

      await tester.tap(protectionSwitch(app));
      await tester.pumpAndSettle();
      expect(find.text(app.s.enterTrustedPersonPin), findsOneWidget);

      await tester.tap(find.text(app.s.cancel));
      await tester.pumpAndSettle();
      expect(app.container.read(uninstallProtectionProvider), isTrue);
      expect(app.screenTime.calls, isEmpty);
    });

    testWidgets('while a profile is active it also takes the cooldown', (
      tester,
    ) async {
      final app = await pumpUnspend(tester, profiles: sampleProfiles());
      expect(app.screenTime.removalLocked, isTrue);
      await openSetting(tester, app, app.s.uninstallProtection);

      await tester.tap(protectionSwitch(app));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('00:03'), findsOneWidget);
      expect(app.screenTime.removalLocked, isTrue);

      await app.elapse(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(app.container.read(uninstallProtectionProvider), isFalse);
      expect(app.screenTime.removalLocked, isFalse);
      expect(
        app.screenTime.isShielded('social'),
        isTrue,
        reason: 'still blocked',
      );
    });
  });

  group('appearance and language', () {
    testWidgets('choosing a language switches the app and the shield text', (
      tester,
    ) async {
      final app = await pumpUnspend(tester);
      addTearDown(() => S.setLocale('en'));
      await openSetting(tester, app, app.s.languageLabel);

      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();

      expect(S.langCode, 'de');
      expect(find.text('Profile'), findsOneWidget);
      expect(app.screenTime.shieldStrings, shieldStrings(S.current));
      expect(app.screenTime.shieldStrings!.button, 'Zurück');
    });

    testWidgets('choosing a theme applies and remembers it', (tester) async {
      final app = await pumpUnspend(tester);
      await openSetting(tester, app, app.s.themeLabel);

      await tester.tap(find.text(app.s.themeLight));
      await tester.pumpAndSettle();

      expect(app.container.read(themeModeProvider), ThemeMode.light);
      expect(app.prefs.getString(ThemeModeNotifier.storageKey), 'light');
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, const Color(0xFFF5F5F5));
    });

    testWidgets('the privacy policy can be read', (tester) async {
      final app = await pumpUnspend(tester);
      await openSetting(tester, app, app.s.privacyPolicyTitle);

      expect(find.text(app.s.privacyPolicyBody), findsOneWidget);
    });

    testWidgets('debug builds offer diagnostics', (tester) async {
      final app = await pumpUnspend(tester, profiles: sampleProfiles());
      await openSetting(tester, app, 'Diagnostics');

      expect(find.textContaining('Authorization: approved'), findsOneWidget);
      expect(find.textContaining('unspend.schedule.social'), findsOneWidget);
    });
  });
}
