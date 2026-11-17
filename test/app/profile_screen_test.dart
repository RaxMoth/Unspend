import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unspend/config/router.dart';
import 'package:unspend/features/app_blocker/data/datasources/screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/domain/entities/blocker_profile.dart';

import '../support/app_harness.dart';

void main() {
  Future<AppHarness> openProfile(
    WidgetTester tester,
    String id, {
    List<BlockerProfile>? profiles,
    ScreenTimeAuthStatus auth = ScreenTimeAuthStatus.approved,
    String? pin,
  }) async {
    final app = await pumpUnspend(
      tester,
      profiles: profiles ?? sampleProfiles(),
      auth: auth,
      authAfterRequest: auth,
      pin: pin,
    );
    await app.open(AppRoutes.profile(id));
    return app;
  }

  Finder rule(String title) => find.bySemanticsLabel(RegExp('^$title'));

  group('editing', () {
    testWidgets('a new name is saved once typing pauses', (tester) async {
      final app = await openProfile(tester, 'games');

      await tester.enterText(find.widgetWithText(TextField, 'Games'), 'Gaming');
      await tester.pump(const Duration(milliseconds: 200));
      expect(app.profile('games').name, 'Games', reason: 'still typing');

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(app.profile('games').name, 'Gaming');
    });

    testWidgets('leaving straight after typing does not lose the name', (
      tester,
    ) async {
      final app = await openProfile(tester, 'games');

      await tester.enterText(find.widgetWithText(TextField, 'Games'), 'Gaming');
      await app.open(AppRoutes.dashboard);

      expect(app.profile('games').name, 'Gaming');
    });

    testWidgets('an emptied name falls back to a default', (tester) async {
      final app = await openProfile(tester, 'games');

      await tester.enterText(find.widgetWithText(TextField, 'Games'), '  ');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(app.profile('games').name, app.s.untitled);
    });

    testWidgets('colour and icon are saved', (tester) async {
      final app = await openProfile(tester, 'games');

      await app.tap(find.bySemanticsLabel(app.s.colorName('Blue')));
      await app.tap(find.bySemanticsLabel(app.s.iconName('Music')));

      expect(app.profile('games').colorValue, 0xFF1E88E5);
      expect(app.profile('games').iconLabel, 'Music');
    });

    testWidgets('turning a rule on shows its settings and saves it', (
      tester,
    ) async {
      final app = await openProfile(tester, 'games');
      expect(find.text(app.s.scheduleStart), findsNothing);

      await app.tap(rule(app.s.scheduleTitle));
      expect(find.text(app.s.scheduleStart), findsOneWidget);
      expect(app.profile('games').scheduleEnabled, isTrue);
      expect(app.profile('games').scheduleStartHour, 9);
      expect(app.profile('games').scheduleEndHour, 17);

      await app.tap(rule(app.s.scheduleTitle));
      expect(find.text(app.s.scheduleStart), findsNothing);
      expect(app.profile('games').scheduleEnabled, isFalse);
    });

    testWidgets('the daily limit can be typed exactly', (tester) async {
      final app = await openProfile(tester, 'news');
      await app.tap(find.text(app.s.dailyLimit));
      await tester.tap(find.text(app.s.pickerModeKeypad));
      await tester.pumpAndSettle();

      final fields = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), '1');
      await tester.enterText(fields.at(1), '99');
      await tester.tap(find.text(app.s.save));
      await tester.pumpAndSettle();

      expect(
        app.profile('news').usageLimitMinutes,
        119,
        reason: 'minutes are capped at 59',
      );
      expect(find.text('1 h 59 min'), findsOneWidget);
    });

    testWidgets('cancelling the daily limit keeps the old value', (
      tester,
    ) async {
      final app = await openProfile(tester, 'news');
      await app.tap(find.text(app.s.dailyLimit));

      await tester.tap(find.text(app.s.cancel));
      await tester.pumpAndSettle();

      expect(app.profile('news').usageLimitMinutes, 45);
    });
  });

  group('apps', () {
    testWidgets('picking apps shows the count and suggests a PIN', (
      tester,
    ) async {
      final app = await openProfile(tester, 'news');

      await app.tap(find.text(app.s.selectAppsToBlock));

      expect(app.screenTime.lastPickerLabels!.title, app.s.pickerTitle);
      expect(app.profile('news').appCount, 3);
      expect(find.text(app.s.setPinTitle), findsOneWidget);

      await tester.tap(find.text(app.s.notNow));
      await tester.pumpAndSettle();
      expect(find.text(app.s.setPinTitle), findsNothing);
      expect(find.text(app.s.appsSelected(3)), findsOneWidget);
      expect(await app.pins.hasPin(), isFalse);
    });

    testWidgets('with a PIN already set, none is suggested', (tester) async {
      final app = await openProfile(tester, 'news', pin: '2468');

      await app.tap(find.text(app.s.selectAppsToBlock));

      expect(find.text(app.s.setPinTitle), findsNothing);
      expect(app.profile('news').hasAppsSelected, isTrue);
    });

    testWidgets('a cancelled picker changes nothing', (tester) async {
      final app = await openProfile(tester, 'news');
      app.screenTime.pickCount = null;

      await app.tap(find.text(app.s.selectAppsToBlock));

      expect(app.profile('news').hasAppsSelected, isFalse);
      expect(find.text(app.s.setPinTitle), findsNothing);
    });

    testWidgets('without Screen Time access the picker is not opened', (
      tester,
    ) async {
      final app = await openProfile(
        tester,
        'news',
        auth: ScreenTimeAuthStatus.denied,
      );

      await app.tap(find.text(app.s.selectAppsToBlock));

      expect(app.screenTime.calls, isNot(contains('pickApps:news')));
      expect(find.text(app.s.errorNotAuthorized), findsOneWidget);
      expect(
        find.widgetWithText(SnackBarAction, app.s.openSettings),
        findsOneWidget,
      );
    });
  });

  group('activating', () {
    testWidgets('the button activates and the screen locks its rules', (
      tester,
    ) async {
      final app = await openProfile(tester, 'games');
      expect(find.byTooltip(app.s.deleteProfile), findsOneWidget);

      await app.tap(find.text(app.s.activateShield));

      expect(app.profile('games').isActive, isTrue);
      expect(find.text(app.s.deactivateShield), findsOneWidget);
      expect(find.text(app.s.settingsLockedWhileActive), findsOneWidget);
      expect(find.text(app.s.reasonManualMode), findsOneWidget);
      expect(
        find.byTooltip(app.s.deleteProfile),
        findsNothing,
        reason: 'an active profile cannot be deleted',
      );
    });

    testWidgets('rules changed just before activating are the ones enforced', (
      tester,
    ) async {
      final app = await openProfile(tester, 'games');

      await app.tap(rule(app.s.usageLimitTitle));
      await app.tap(find.text(app.s.activateShield));

      expect(app.screenTime.active['games']!.usageLimitMinutes, 30);
      expect(
        app.screenTime.isShielded('games'),
        isFalse,
        reason: 'limit unused',
      );
    });

    testWidgets('without apps the button says what is missing', (tester) async {
      final app = await openProfile(tester, 'news');

      await app.tap(find.text(app.s.selectAppsToActivate));

      expect(find.text(app.s.noAppsWarning), findsOneWidget);
      expect(app.profile('news').isActive, isFalse);
    });

    testWidgets('task mode without tasks cannot be activated', (tester) async {
      final app = await openProfile(tester, 'games');
      await app.tap(rule(app.s.taskModeTitle));

      await app.tap(find.text(app.s.activateShield));

      expect(find.text(app.s.noTasksWarning), findsOneWidget);
      expect(app.profile('games').isActive, isFalse);
    });

    testWidgets('a schedule under 15 minutes is flagged and refused', (
      tester,
    ) async {
      final app = await openProfile(
        tester,
        'short',
        profiles: const [
          BlockerProfile(
            id: 'short',
            name: 'Short',
            hasAppsSelected: true,
            appCount: 1,
            scheduleEnabled: true,
            scheduleStartHour: 9,
            scheduleStartMinute: 0,
            scheduleEndHour: 9,
            scheduleEndMinute: 10,
          ),
        ],
      );
      expect(find.text(app.s.errorScheduleTooShort), findsOneWidget);

      await app.tap(find.text(app.s.activateShield));

      expect(app.profile('short').isActive, isFalse);
      expect(app.screenTime.calls, isNot(contains('activate:short')));
      expect(find.text(app.s.errorScheduleTooShort), findsNWidgets(2));
    });

    testWidgets('an active profile shows why it is blocking', (tester) async {
      final app = await openProfile(tester, 'social');

      expect(find.textContaining(app.s.reasonInsideSchedule), findsOneWidget);
      expect(find.text(app.s.deactivateShield), findsOneWidget);
    });

    testWidgets('the rules of an active profile cannot be switched', (
      tester,
    ) async {
      final app = await openProfile(tester, 'social');

      await app.tap(rule(app.s.scheduleTitle));
      await app.tap(rule(app.s.taskModeTitle));

      expect(app.profile('social').scheduleEnabled, isTrue);
      expect(app.profile('social').taskModeEnabled, isTrue);
    });

    testWidgets('an active profile can still be renamed', (tester) async {
      final app = await openProfile(tester, 'social');

      await tester.enterText(find.byType(TextField).first, 'Focus');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(app.profile('social').name, 'Focus');
      expect(app.profile('social').isActive, isTrue);
    });
  });

  group('tasks', () {
    const withTasks = BlockerProfile(
      id: 'chores',
      name: 'Chores',
      hasAppsSelected: true,
      appCount: 2,
      taskModeEnabled: true,
      tasks: [BlockerTask(id: 'a', title: 'Dishes')],
    );

    testWidgets('can be added, ticked and removed', (tester) async {
      final app = await openProfile(tester, 'chores', profiles: [withTasks]);

      await tester.enterText(
        find.widgetWithText(TextField, app.s.addTaskHint),
        'Laundry',
      );
      await app.tap(find.byTooltip(app.s.addTask));
      expect(app.profile('chores').tasks.map((t) => t.title), [
        'Dishes',
        'Laundry',
      ]);
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, app.s.addTaskHint),
            )
            .controller!
            .text,
        isEmpty,
      );

      await app.tap(find.text('Dishes'));
      expect(app.profile('chores').tasks.first.isDone, isTrue);
      expect(find.text('1 / 2'), findsOneWidget);

      await app.tap(find.byTooltip(app.s.deleteTaskLabel('Dishes')));
      expect(app.profile('chores').tasks.map((t) => t.title), ['Laundry']);
    });

    testWidgets('an empty task is not added', (tester) async {
      final app = await openProfile(tester, 'chores', profiles: [withTasks]);

      await app.tap(find.byTooltip(app.s.addTask));

      expect(app.profile('chores').tasks, hasLength(1));
    });

    testWidgets('while active, tasks can be ticked but not changed', (
      tester,
    ) async {
      final app = await openProfile(tester, 'social');

      expect(find.byTooltip(app.s.addTask), findsNothing);
      expect(
        find.byTooltip(app.s.deleteTaskLabel('Go for a run')),
        findsNothing,
      );
      expect(find.text(app.s.tasksRemainingNote(1)), findsOneWidget);

      await app.tap(find.text('Go for a run'));
      expect(app.profile('social').allTasksDone, isTrue);
      expect(find.text(app.s.allTasksDoneNote), findsOneWidget);
    });
  });

  group('leaving', () {
    testWidgets('deleting returns to the dashboard without the profile', (
      tester,
    ) async {
      final app = await pumpUnspend(tester, profiles: sampleProfiles());
      await app.tap(find.text('Games'));

      await tester.tap(find.byTooltip(app.s.deleteProfile));
      await tester.pumpAndSettle();
      expect(find.text(app.s.deleteProfileConfirm('Games')), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, app.s.delete));
      await tester.pumpAndSettle();

      expect(app.profiles.map((p) => p.id), ['social', 'news']);
      expect(app.screenTime.calls, contains('deleteProfile:games'));
      expect(find.text(app.s.profilesSectionTitle), findsOneWidget);
      expect(find.text('Games'), findsNothing);
    });

    testWidgets('cancelling the delete dialog keeps the profile', (
      tester,
    ) async {
      final app = await openProfile(tester, 'games');

      await tester.tap(find.byTooltip(app.s.deleteProfile));
      await tester.pumpAndSettle();
      await tester.tap(find.text(app.s.cancel));
      await tester.pumpAndSettle();

      expect(app.profiles, hasLength(3));
    });

    testWidgets('a link to a profile that does not exist opens the dashboard', (
      tester,
    ) async {
      final app = await pumpUnspend(tester, profiles: sampleProfiles());

      await app.open(AppRoutes.profile('gone'));

      expect(find.text(app.s.profilesSectionTitle), findsOneWidget);
    });
  });
}
