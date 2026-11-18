import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unspend/features/app_blocker/data/datasources/screen_time_datasource.dart';

import '../support/app_harness.dart';

void main() {
  Finder activateSwitch(AppHarness app, String name) =>
      find.bySemanticsLabel('${app.s.activateShield}, $name');
  Finder deactivateSwitch(AppHarness app, String name) =>
      find.bySemanticsLabel('${app.s.deactivateShield}, $name');

  group('profiles', () {
    testWidgets('without profiles the dashboard says how to start', (
      tester,
    ) async {
      final app = await pumpUnspend(tester);

      expect(find.text(app.s.noProfiles), findsOneWidget);
      expect(find.text(app.s.noProfilesYet), findsOneWidget);
    });

    testWidgets('the summary counts active profiles', (tester) async {
      final app = await pumpUnspend(tester, profiles: sampleProfiles());

      expect(find.text(app.s.someShieldsActive(1, 3)), findsOneWidget);
      expect(find.text('Games'), findsOneWidget);
    });

    testWidgets('creating a profile opens its screen', (tester) async {
      final app = await pumpUnspend(tester);

      await tester.tap(find.byTooltip(app.s.newProfile));
      await tester.pumpAndSettle();
      expect(
        tester.testTextInput.isVisible,
        isTrue,
        reason: 'the name field is focused, the keyboard is up',
      );

      await tester.enterText(find.byType(TextField), '  Evening  ');
      await tester.tap(find.text(app.s.create));
      await tester.pumpAndSettle();

      expect(app.profiles.single.name, 'Evening');
      expect(find.widgetWithText(TextField, 'Evening'), findsOneWidget);
      expect(find.text(app.s.sectionBlockRules), findsOneWidget);
    });

    testWidgets('a profile needs a name', (tester) async {
      final app = await pumpUnspend(tester);
      await tester.tap(find.byTooltip(app.s.newProfile));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text(app.s.create));
      await tester.pumpAndSettle();

      expect(app.profiles, isEmpty);
      expect(find.text(app.s.createProfileDescription), findsOneWidget);
    });

    testWidgets('tapping a card opens the profile', (tester) async {
      final app = await pumpUnspend(tester, profiles: sampleProfiles());

      await tester.tap(find.text('Games'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Games'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text(app.s.profilesSectionTitle), findsOneWidget);
    });
  });

  group('switching profiles on and off', () {
    testWidgets('the switch activates a profile', (tester) async {
      final app = await pumpUnspend(tester, profiles: sampleProfiles());

      await app.tap(activateSwitch(app, 'Games'));

      expect(app.profile('games').isActive, isTrue);
      expect(app.screenTime.isShielded('games'), isTrue);
      expect(deactivateSwitch(app, 'Games'), findsOneWidget);
    });

    testWidgets('a profile without apps says what is missing', (tester) async {
      final app = await pumpUnspend(tester, profiles: sampleProfiles());

      await app.tap(activateSwitch(app, 'News'));

      expect(find.text(app.s.noAppsWarning), findsOneWidget);
      expect(app.profile('news').isActive, isFalse);
    });

    testWidgets('activation refused by the OS is explained', (tester) async {
      final app = await pumpUnspend(tester, profiles: sampleProfiles());
      app.screenTime.failNext = const ScreenTimeException(
        ScreenTimeError.tooManyActivities,
      );

      await app.tap(activateSwitch(app, 'Games'));

      expect(find.text(app.s.errorTooManyActivities), findsOneWidget);
      expect(app.profile('games').isActive, isFalse);
    });

    testWidgets('lost Screen Time access is explained with a way to fix it', (
      tester,
    ) async {
      final app = await pumpUnspend(tester, profiles: sampleProfiles());
      app.screenTime.authStatus = ScreenTimeAuthStatus.denied;

      await app.tap(activateSwitch(app, 'Games'));

      expect(find.text(app.s.errorNotAuthorized), findsOneWidget);
      expect(
        find.text(app.s.authBannerTitle),
        findsOneWidget,
        reason: 'the banner appears once the loss is noticed',
      );
      await tester.tap(find.widgetWithText(SnackBarAction, app.s.openSettings));
      await tester.pump();
      expect(app.screenTime.settingsOpened, isTrue);
    });

    testWidgets('deactivating waits for the cooldown, then asks once', (
      tester,
    ) async {
      final app = await pumpUnspend(tester, profiles: sampleProfiles());

      await tester.tap(
        deactivateSwitch(app, 'Social media and endless scrolling'),
      );
      await tester.pump();
      expect(find.text('00:03'), findsOneWidget);
      expect(
        find.text(app.s.deactivateAction),
        findsOneWidget,
        reason: 'title',
      );

      await app.elapse(const Duration(seconds: 1));
      expect(find.text('00:02'), findsOneWidget);
      expect(app.profile('social').isActive, isTrue);

      await app.elapse(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text(app.s.areYouSureDeactivate), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, app.s.deactivateAction));
      await tester.pumpAndSettle();

      expect(app.profile('social').isActive, isFalse);
      expect(app.screenTime.isShielded('social'), isFalse);
      expect(find.text(app.s.shieldsInactive), findsOneWidget);
    });

    testWidgets('cancelling during the cooldown keeps the block', (
      tester,
    ) async {
      final app = await pumpUnspend(tester, profiles: sampleProfiles());

      await tester.tap(
        deactivateSwitch(app, 'Social media and endless scrolling'),
      );
      await tester.pump();
      await tester.tap(find.text(app.s.cancel));
      await tester.pumpAndSettle();

      expect(app.profile('social').isActive, isTrue);
      expect(app.screenTime.calls, isNot(contains('deactivate:social')));
    });

    testWidgets('a block the OS will not lift is reported', (tester) async {
      final app = await pumpUnspend(
        tester,
        profiles: sampleProfiles(),
        cooldown: Duration.zero,
      );
      await tester.tap(
        deactivateSwitch(app, 'Social media and endless scrolling'),
      );
      await tester.pumpAndSettle();
      app.screenTime.failNext = const ScreenTimeException(
        ScreenTimeError.unknown,
      );

      await tester.tap(find.widgetWithText(TextButton, app.s.deactivateAction));
      await tester.pumpAndSettle();

      expect(find.text(app.s.deactivationFailed), findsOneWidget);
      expect(app.profile('social').isActive, isTrue);
    });
  });

  group('tasks on the card', () {
    testWidgets('ticking the last task tells the OS', (tester) async {
      final app = await pumpUnspend(tester, profiles: sampleProfiles());

      await tester.tap(find.text('Go for a run'));
      await tester.pumpAndSettle();

      expect(app.profile('social').allTasksDone, isTrue);
      expect(app.screenTime.calls, ['setTasksDone:social:true']);
      expect(
        app.screenTime.isShielded('social'),
        isTrue,
        reason: 'still inside the schedule window',
      );
    });
  });

  group('Screen Time banner', () {
    testWidgets('is hidden when access is granted', (tester) async {
      final app = await pumpUnspend(tester);

      expect(find.text(app.s.authBannerTitle), findsNothing);
    });

    testWidgets('asks for access and disappears once granted', (tester) async {
      final app = await pumpUnspend(
        tester,
        auth: ScreenTimeAuthStatus.notDetermined,
      );
      expect(find.text(app.s.authBannerTitle), findsOneWidget);
      expect(find.text(app.s.openSettings), findsNothing);

      await tester.tap(find.text(app.s.authAllow));
      await tester.pumpAndSettle();

      expect(app.screenTime.calls, ['requestAuthorization:individual']);
      expect(find.text(app.s.authBannerTitle), findsNothing);
    });

    testWidgets('after a refusal it points to Settings', (tester) async {
      final app = await pumpUnspend(
        tester,
        auth: ScreenTimeAuthStatus.denied,
        authAfterRequest: ScreenTimeAuthStatus.denied,
      );

      await tester.tap(find.text(app.s.authAllow));
      await tester.pumpAndSettle();
      expect(find.text(app.s.authDeniedHint), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, app.s.openSettings));
      await tester.pump();
      expect(app.screenTime.settingsOpened, isTrue);
    });
  });
}
