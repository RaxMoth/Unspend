import 'package:flutter_test/flutter_test.dart';
import 'package:unspend/config/router.dart';
import 'package:unspend/core/providers.dart';
import 'package:unspend/features/app_blocker/data/datasources/screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/presentation/providers/device_mode_provider.dart';

import '../support/app_harness.dart';

void main() {
  Future<AppHarness> firstLaunch(
    WidgetTester tester, {
    ScreenTimeAuthStatus answer = ScreenTimeAuthStatus.approved,
    bool isChildAccount = true,
  }) => pumpUnspend(
    tester,
    onboardingSeen: false,
    auth: ScreenTimeAuthStatus.notDetermined,
    authAfterRequest: answer,
    isChildAccount: isChildAccount,
  );

  Future<void> next(
    WidgetTester tester,
    AppHarness app, {
    int times = 1,
  }) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.text(app.s.next));
      await tester.pumpAndSettle();
    }
  }

  /// Past the three introduction pages, on "Who uses this iPhone?".
  Future<void> goToWhoPage(WidgetTester tester, AppHarness app) =>
      next(tester, app, times: 3);

  Future<void> goToPermissionPage(WidgetTester tester, AppHarness app) =>
      next(tester, app, times: 4);

  Future<void> chooseChild(WidgetTester tester, AppHarness app) async {
    await app.tap(find.bySemanticsLabel(RegExp('^${app.s.modeChildTitle}')));
  }

  testWidgets('the first launch starts with the introduction', (tester) async {
    final app = await firstLaunch(tester);

    expect(find.text(app.s.onboardingTitle1), findsOneWidget);
    expect(app.screenTime.calls, isEmpty, reason: 'no prompt before asking');
  });

  testWidgets('the last page asks for access and leads to the dashboard', (
    tester,
  ) async {
    final app = await firstLaunch(tester);
    await goToPermissionPage(tester, app);
    expect(find.text(app.s.onboardingTitle4), findsOneWidget);
    expect(find.text(app.s.onboardingBody4), findsOneWidget);

    await tester.tap(find.text(app.s.authAllow));
    await tester.pumpAndSettle();
    expect(app.screenTime.calls, contains('requestAuthorization:individual'));
    expect(find.text(app.s.authGranted), findsOneWidget);

    await tester.tap(find.text(app.s.getStarted));
    await tester.pumpAndSettle();
    expect(find.text(app.s.profilesSectionTitle), findsOneWidget);
    expect(find.text(app.s.authBannerTitle), findsNothing);
    expect(app.prefs.getBool(kHasSeenOnboardingKey), isTrue);
  });

  testWidgets('refused access is explained and can be postponed', (
    tester,
  ) async {
    final app = await firstLaunch(tester, answer: ScreenTimeAuthStatus.denied);
    await goToPermissionPage(tester, app);

    await tester.tap(find.text(app.s.authAllow));
    await tester.pumpAndSettle();
    expect(find.text(app.s.authDeniedHint), findsOneWidget);
    expect(find.text(app.s.getStarted), findsNothing);

    await tester.tap(find.text(app.s.notNow));
    await tester.pumpAndSettle();
    expect(find.text(app.s.authBannerTitle), findsOneWidget);
  });

  testWidgets('skipping goes to the dashboard without a prompt', (
    tester,
  ) async {
    final app = await firstLaunch(tester);

    await tester.tap(find.text(app.s.skip));
    await tester.pumpAndSettle();

    expect(find.text(app.s.profilesSectionTitle), findsOneWidget);
    expect(app.screenTime.calls, isEmpty);
    expect(find.text(app.s.authBannerTitle), findsOneWidget);
  });

  testWidgets('pages can be swiped', (tester) async {
    final app = await firstLaunch(tester);

    await tester.fling(
      find.text(app.s.onboardingTitle1),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text(app.s.onboardingTitle2), findsOneWidget);
  });

  group('who uses this iPhone', () {
    testWidgets('"my iPhone" is selected unless changed', (tester) async {
      final app = await firstLaunch(tester);
      await goToWhoPage(tester, app);

      expect(find.text(app.s.whoUsesTitle), findsOneWidget);
      expect(app.container.read(deviceModeProvider), DeviceMode.personal);
    });

    testWidgets('on a child\'s iPhone a parent approves', (tester) async {
      final app = await firstLaunch(tester);
      await goToWhoPage(tester, app);

      await chooseChild(tester, app);
      expect(app.container.read(deviceModeProvider), DeviceMode.child);
      expect(app.prefs.getString(DeviceModeNotifier.storageKey), 'child');

      await next(tester, app);
      expect(find.text(app.s.onboardingBody4Child), findsOneWidget);

      await tester.tap(find.text(app.s.authAllow));
      await tester.pumpAndSettle();
      expect(app.screenTime.calls, ['requestAuthorization:child']);
      expect(app.screenTime.authorizedMember, ScreenTimeMember.child);
      expect(find.text(app.s.authGranted), findsOneWidget);
    });

    testWidgets('a phone that is not a child\'s says so and lets you go back', (
      tester,
    ) async {
      final app = await firstLaunch(tester, isChildAccount: false);
      await goToWhoPage(tester, app);
      await chooseChild(tester, app);
      await next(tester, app);

      await tester.tap(find.text(app.s.authAllow));
      await tester.pumpAndSettle();
      expect(find.text(app.s.authNotChildAccount), findsOneWidget);
      expect(find.text(app.s.getStarted), findsNothing);

      // Back to the choice, pick "my iPhone", ask again.
      await tester.fling(
        find.text(app.s.onboardingTitle4),
        const Offset(300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      await app.tap(
        find.bySemanticsLabel(RegExp('^${app.s.modePersonalTitle}')),
      );
      await next(tester, app);
      expect(
        find.text(app.s.authNotChildAccount),
        findsNothing,
        reason: 'the refusal belonged to the other choice',
      );

      await tester.tap(find.text(app.s.authAllow));
      await tester.pumpAndSettle();
      expect(app.screenTime.calls.last, 'requestAuthorization:individual');
      expect(find.text(app.s.authGranted), findsOneWidget);
    });
  });

  testWidgets('the introduction is not shown a second time', (tester) async {
    final app = await pumpUnspend(tester);
    expect(find.text(app.s.profilesSectionTitle), findsOneWidget);

    await app.open(AppRoutes.onboarding);
    expect(find.text(app.s.onboardingTitle1), findsNothing);
    expect(find.text(app.s.profilesSectionTitle), findsOneWidget);
  });

  testWidgets('an unknown address shows a way back', (tester) async {
    final app = await pumpUnspend(tester);

    await app.open('/no/such/page');
    expect(find.text(app.s.pageNotFound), findsOneWidget);

    await tester.tap(find.text(app.s.goHome));
    await tester.pumpAndSettle();
    expect(find.text(app.s.profilesSectionTitle), findsOneWidget);
  });
}
