import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unspend/config/router.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/features/app_blocker/data/datasources/screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/domain/entities/blocker_profile.dart';
import 'package:unspend/features/app_blocker/presentation/native_strings.dart';
import 'package:unspend/features/app_blocker/presentation/providers/profiles_provider.dart';

import '../support/app_harness.dart';

Future<void> _background(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
}

Future<void> _foreground(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('on start the profiles are synced and the shield text is set', (
    tester,
  ) async {
    final app = await pumpUnspend(tester, profiles: sampleProfiles());

    expect(
      app.container.read(shieldStatusProvider)['social'],
      const ShieldStatus(shielded: true, limitReachedToday: false),
    );
    expect(app.screenTime.shieldStrings, shieldStrings(S.current));
  });

  testWidgets('returning to the app syncs again', (tester) async {
    final app = await pumpUnspend(tester, profiles: sampleProfiles());
    await _background(tester);
    // While the app was away the schedule ended and the limit ran out.
    app.now = DateTime(2026, 11, 17, 18);
    app.screenTime.reachLimit('social');

    await _foreground(tester);

    expect(app.screenTime.calls, ['sync:social']);
    expect(
      app.container.read(shieldStatusProvider)['social'],
      const ShieldStatus(shielded: true, limitReachedToday: true),
    );
    expect(
      find.bySemanticsLabel(RegExp(app.s.reasonLimitReached)),
      findsOneWidget,
    );
  });

  testWidgets('access granted in Settings is noticed on return', (
    tester,
  ) async {
    final app = await pumpUnspend(tester, auth: ScreenTimeAuthStatus.denied);
    expect(find.text(app.s.authBannerTitle), findsOneWidget);

    await _background(tester);
    app.screenTime.authStatus = ScreenTimeAuthStatus.approved;
    await _foreground(tester);

    expect(find.text(app.s.authBannerTitle), findsNothing);
  });

  testWidgets('a block the OS dropped shows as inactive on return', (
    tester,
  ) async {
    final app = await pumpUnspend(tester, profiles: sampleProfiles());
    await _background(tester);
    app.screenTime.active.remove('social');

    await _foreground(tester);

    expect(app.profile('social').isActive, isFalse);
    expect(find.text(app.s.shieldsInactive), findsOneWidget);
  });

  testWidgets('a schedule starting while the app is open shows as blocking', (
    tester,
  ) async {
    final start = DateTime(2026, 11, 17, 12, 0, 30);
    final app = await pumpUnspend(
      tester,
      now: start,
      profiles: [
        BlockerProfile(
          id: 'lunch',
          name: 'Lunch',
          hasAppsSelected: true,
          appCount: 1,
          scheduleEnabled: true,
          scheduleStartHour: 12,
          scheduleStartMinute: 1,
          scheduleEndHour: 13,
          scheduleEndMinute: 0,
          isActive: true,
          shieldActivatedAt: start.toIso8601String(),
          tasksLastResetDate: '2026-11-17',
        ),
      ],
    );
    expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);

    await app.elapse(const Duration(seconds: 31));

    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(app.screenTime.calls, isEmpty, reason: 'no OS call needed for this');
  });

  testWidgets('at midnight the tasks reset while the app is open', (
    tester,
  ) async {
    final lateEvening = DateTime(2026, 11, 17, 23, 59, 30);
    final app = await pumpUnspend(
      tester,
      now: lateEvening,
      profiles: [
        BlockerProfile(
          id: 'chores',
          name: 'Chores',
          hasAppsSelected: true,
          appCount: 1,
          taskModeEnabled: true,
          tasks: const [BlockerTask(id: 'a', title: 'Dishes', isDone: true)],
          isActive: true,
          shieldActivatedAt: lateEvening.toIso8601String(),
          tasksLastResetDate: '2026-11-17',
        ),
      ],
    );
    expect(app.screenTime.isShielded('chores'), isFalse, reason: 'tasks done');

    await app.elapse(const Duration(seconds: 31));
    await tester.pumpAndSettle();

    expect(app.profile('chores').tasks.single.isDone, isFalse);
    expect(app.profile('chores').tasksLastResetDate, '2026-11-18');
    expect(app.screenTime.isShielded('chores'), isTrue);
    expect(app.screenTime.calls, ['sync:chores']);
  });

  testWidgets('system text beyond the largest supported size is capped', (
    tester,
  ) async {
    await pumpUnspend(tester, textScale: 3);

    final scaler = MediaQuery.textScalerOf(
      tester.element(find.byType(Scaffold).first),
    );
    expect(scaler.scale(10), 10 * AppTextScale.max);
  });

  testWidgets('system text between the limits is honoured', (tester) async {
    await pumpUnspend(tester, textScale: 1.3);

    final scaler = MediaQuery.textScalerOf(
      tester.element(find.byType(Scaffold).first),
    );
    expect(scaler.scale(10), 13);
  });

  testWidgets('the app follows the system switching to light mode', (
    tester,
  ) async {
    final app = await pumpUnspend(tester, profiles: sampleProfiles());
    AppColors colors() => tester.element(find.text('Games')).colors;
    Color nameColor() => tester.widget<Text>(find.text('Games')).style!.color!;
    expect(colors(), AppColors.dark);
    expect(nameColor(), AppColors.dark.textPrimary);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();

    expect(colors(), AppColors.light);
    expect(nameColor(), AppColors.light.textPrimary);
    expect(app.profiles, hasLength(3));
  });

  testWidgets('Increase Contrast selects the stronger palette', (tester) async {
    await pumpUnspend(tester, profiles: sampleProfiles());
    AppColors colors() => tester.element(find.text('Games')).colors;
    expect(colors(), AppColors.dark);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(highContrast: true);
    await tester.pumpAndSettle();
    expect(colors(), AppColors.darkHighContrast);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(colors(), AppColors.lightHighContrast);
  });

  group('with Reduce Motion', () {
    testWidgets('animations take no time', (tester) async {
      await pumpUnspend(tester, profiles: sampleProfiles(), reduceMotion: true);

      final context = tester.element(find.text('Games'));
      expect(context.motion(AppDurations.medium), Duration.zero);
    });

    testWidgets('the introduction changes pages without sliding', (
      tester,
    ) async {
      final app = await pumpUnspend(
        tester,
        onboardingSeen: false,
        reduceMotion: true,
      );

      for (var page = 0; page < 4; page++) {
        await tester.tap(find.text(app.s.next));
        await tester.pump();
      }

      expect(find.text(app.s.onboardingTitle4), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rule settings appear and disappear at once', (tester) async {
      final app = await pumpUnspend(
        tester,
        profiles: sampleProfiles(),
        reduceMotion: true,
      );
      await app.open(AppRoutes.profile('games'));
      // The rule's card; once it is on, its settings carry the title too.
      final schedule = find
          .bySemanticsLabel(RegExp('^${app.s.scheduleTitle}'))
          .first;

      await tester.ensureVisible(schedule);
      await tester.pump();
      await tester.tap(schedule);
      await tester.pump();
      expect(find.text(app.s.scheduleStart), findsOneWidget);

      await tester.tap(schedule);
      await tester.pump();
      expect(find.text(app.s.scheduleStart), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
