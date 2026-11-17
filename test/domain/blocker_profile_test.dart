import 'package:flutter_test/flutter_test.dart';
import 'package:unspend/features/app_blocker/domain/entities/blocker_profile.dart';

void main() {
  group('BlockerTask JSON round-trip', () {
    test('preserves all fields', () {
      const task = BlockerTask(id: 't1', title: 'Read', isDone: true);
      final restored = BlockerTask.fromJson(task.toJson());
      expect(restored.id, task.id);
      expect(restored.title, task.title);
      expect(restored.isDone, task.isDone);
    });

    test('fromJson tolerates missing/null fields with safe defaults', () {
      final t = BlockerTask.fromJson(<String, dynamic>{});
      expect(t.id, '');
      expect(t.title, '');
      expect(t.isDone, false);
    });
  });

  group('BlockerProfile JSON round-trip', () {
    test('preserves every field including nested tasks', () {
      const profile = BlockerProfile(
        id: 'p1',
        name: 'Focus',
        colorValue: 0xFF1E88E5,
        iconLabel: 'Work',
        isActive: true,
        scheduleEnabled: true,
        scheduleStartHour: 22,
        scheduleStartMinute: 30,
        scheduleEndHour: 6,
        scheduleEndMinute: 15,
        usageLimitEnabled: true,
        usageLimitMinutes: 90,
        taskModeEnabled: true,
        tasks: [
          BlockerTask(id: 'a', title: 'Task A', isDone: false),
          BlockerTask(id: 'b', title: 'Task B', isDone: true),
        ],
        hasAppsSelected: true,
        appCount: 12,
        tasksLastResetDate: '2026-07-06',
        shieldActivatedAt: '2026-07-06T08:00:00.000Z',
        totalSavedMinutes: 240,
      );

      final restored = BlockerProfile.fromJson(profile.toJson());

      expect(restored.id, profile.id);
      expect(restored.name, profile.name);
      expect(restored.colorValue, profile.colorValue);
      expect(restored.iconLabel, profile.iconLabel);
      expect(restored.isActive, profile.isActive);
      expect(restored.scheduleEnabled, profile.scheduleEnabled);
      expect(restored.scheduleStartHour, profile.scheduleStartHour);
      expect(restored.scheduleStartMinute, profile.scheduleStartMinute);
      expect(restored.scheduleEndHour, profile.scheduleEndHour);
      expect(restored.scheduleEndMinute, profile.scheduleEndMinute);
      expect(restored.usageLimitEnabled, profile.usageLimitEnabled);
      expect(restored.usageLimitMinutes, profile.usageLimitMinutes);
      expect(restored.taskModeEnabled, profile.taskModeEnabled);
      expect(restored.tasks.length, 2);
      expect(restored.tasks[1].isDone, true);
      expect(restored.hasAppsSelected, profile.hasAppsSelected);
      expect(restored.appCount, profile.appCount);
      expect(restored.tasksLastResetDate, profile.tasksLastResetDate);
      expect(restored.shieldActivatedAt, profile.shieldActivatedAt);
      expect(restored.totalSavedMinutes, profile.totalSavedMinutes);
    });

    test('fromJson clamps out-of-range values from corrupt storage', () {
      final restored = BlockerProfile.fromJson({
        'id': 'x',
        'name': 'Corrupt',
        'scheduleStartHour': 99,
        'scheduleStartMinute': -5,
        'scheduleEndHour': -1,
        'scheduleEndMinute': 250,
        'usageLimitMinutes': 99999,
        'appCount': -3,
        'totalSavedMinutes': -100,
      });
      expect(restored.scheduleStartHour, 23);
      expect(restored.scheduleStartMinute, 0);
      expect(restored.scheduleEndHour, 0);
      expect(restored.scheduleEndMinute, 59);
      expect(restored.usageLimitMinutes, 1439);
      expect(restored.appCount, 0);
      expect(restored.totalSavedMinutes, 0);
    });

    test('fromJson fills defaults for an empty map', () {
      final p = BlockerProfile.fromJson(<String, dynamic>{});
      expect(p.id, '');
      expect(p.name, 'Untitled');
      expect(p.colorValue, 0xFFE53935);
      expect(p.iconLabel, 'Custom');
      expect(p.isActive, false);
      expect(p.tasks, isEmpty);
    });
  });

  group('Schedule window math (overnight-safe)', () {
    BlockerProfile window(int sh, int sm, int eh, int em) => BlockerProfile(
      id: 's',
      name: 'S',
      scheduleEnabled: true,
      scheduleStartHour: sh,
      scheduleStartMinute: sm,
      scheduleEndHour: eh,
      scheduleEndMinute: em,
    );

    int at(int h, int m) => h * 60 + m;

    test('daytime window 09:00–17:00', () {
      final p = window(9, 0, 17, 0);
      expect(p.isMinuteInsideScheduleWindow(at(8, 59)), false);
      expect(p.isMinuteInsideScheduleWindow(at(9, 0)), true); // inclusive start
      expect(p.isMinuteInsideScheduleWindow(at(12, 30)), true);
      expect(p.isMinuteInsideScheduleWindow(at(17, 0)), false); // exclusive end
      expect(p.isMinuteInsideScheduleWindow(at(23, 0)), false);
    });

    test('overnight window 22:00–06:00 spans midnight', () {
      final p = window(22, 0, 6, 0);
      expect(
        p.isMinuteInsideScheduleWindow(at(22, 0)),
        true,
      ); // inclusive start
      expect(p.isMinuteInsideScheduleWindow(at(23, 59)), true);
      expect(p.isMinuteInsideScheduleWindow(at(0, 0)), true);
      expect(p.isMinuteInsideScheduleWindow(at(5, 59)), true);
      expect(p.isMinuteInsideScheduleWindow(at(6, 0)), false); // exclusive end
      expect(p.isMinuteInsideScheduleWindow(at(12, 0)), false);
      expect(p.isMinuteInsideScheduleWindow(at(21, 59)), false);
    });

    test('overnight window with minutes 23:30–06:15', () {
      final p = window(23, 30, 6, 15);
      expect(p.isMinuteInsideScheduleWindow(at(23, 29)), false);
      expect(p.isMinuteInsideScheduleWindow(at(23, 30)), true);
      expect(p.isMinuteInsideScheduleWindow(at(6, 14)), true);
      expect(p.isMinuteInsideScheduleWindow(at(6, 15)), false);
    });

    test('returns false when schedule disabled or unset', () {
      const disabled = BlockerProfile(id: 'd', name: 'D');
      expect(disabled.isMinuteInsideScheduleWindow(at(12, 0)), false);

      const enabledButNoTimes = BlockerProfile(
        id: 'e',
        name: 'E',
        scheduleEnabled: true,
      );
      expect(enabledButNoTimes.isMinuteInsideScheduleWindow(at(12, 0)), false);
    });
  });

  group('Derived requirement getters', () {
    test('isManualOnly true only when no rules enabled', () {
      const manual = BlockerProfile(id: 'm', name: 'M');
      expect(manual.isManualOnly, true);

      const scheduled = BlockerProfile(
        id: 's',
        name: 'S',
        scheduleEnabled: true,
      );
      expect(scheduled.isManualOnly, false);
    });

    test('allTasksDone requires a non-empty, fully-done list', () {
      const none = BlockerProfile(id: 'a', name: 'A', tasks: []);
      expect(none.allTasksDone, false);

      const partial = BlockerProfile(
        id: 'b',
        name: 'B',
        tasks: [
          BlockerTask(id: '1', title: 'x', isDone: true),
          BlockerTask(id: '2', title: 'y', isDone: false),
        ],
      );
      expect(partial.allTasksDone, false);
      expect(partial.pendingTaskCount, 1);

      const done = BlockerProfile(
        id: 'c',
        name: 'C',
        tasks: [BlockerTask(id: '1', title: 'x', isDone: true)],
      );
      expect(done.allTasksDone, true);
      expect(done.pendingTaskCount, 0);
    });

    test('doneTaskCount and hasPendingTasks follow the task list', () {
      const p = BlockerProfile(
        id: 'p',
        name: 'P',
        taskModeEnabled: true,
        tasks: [
          BlockerTask(id: '1', title: 'x', isDone: true),
          BlockerTask(id: '2', title: 'y'),
        ],
      );
      expect(p.doneTaskCount, 1);
      expect(p.hasPendingTasks, true);

      // Task mode off: tasks never hold a block.
      expect(p.copyWith(taskModeEnabled: false).hasPendingTasks, false);
    });

    test('schedule validity needs a window of at least 15 minutes', () {
      BlockerProfile window(int sh, int sm, int eh, int em) => BlockerProfile(
        id: 's',
        name: 'S',
        scheduleEnabled: true,
        scheduleStartHour: sh,
        scheduleStartMinute: sm,
        scheduleEndHour: eh,
        scheduleEndMinute: em,
      );

      expect(window(9, 0, 17, 0).hasValidSchedule, true);
      expect(window(22, 0, 6, 0).hasValidSchedule, true);
      expect(window(9, 0, 9, 0).hasValidSchedule, false);
      expect(window(9, 0, 9, 10).hasValidSchedule, false);
      expect(
        const BlockerProfile(id: 'n', name: 'N').hasValidSchedule,
        false,
        reason: 'schedule rule is off',
      );
    });
  });

  group('isBlockingAt', () {
    final noon = DateTime(2026, 11, 17, 12);
    final evening = DateTime(2026, 11, 17, 20);

    const base = BlockerProfile(id: 'p', name: 'P', isActive: true);
    const pendingTask = [BlockerTask(id: '1', title: 'x')];
    const doneTask = [BlockerTask(id: '1', title: 'x', isDone: true)];

    BlockerProfile scheduled(BlockerProfile p) => p.copyWith(
      scheduleEnabled: true,
      scheduleStartHour: 9,
      scheduleStartMinute: 0,
      scheduleEndHour: 17,
      scheduleEndMinute: 0,
    );

    test('an inactive profile never blocks', () {
      const p = BlockerProfile(id: 'p', name: 'P');
      expect(p.isBlockingAt(noon), false);
      expect(scheduled(p).isBlockingAt(noon), false);
    });

    test('manual-only blocks for as long as it is active', () {
      expect(base.isBlockingAt(noon), true);
      expect(base.isBlockingAt(evening), true);
    });

    test('schedule blocks inside the window only', () {
      final p = scheduled(base);
      expect(p.isBlockingAt(noon), true);
      expect(p.isBlockingAt(evening), false);
    });

    test('task mode blocks until every task is done', () {
      final p = base.copyWith(taskModeEnabled: true, tasks: pendingTask);
      expect(p.isBlockingAt(noon), true);
      expect(p.copyWith(tasks: doneTask).isBlockingAt(noon), false);
    });

    test('usage limit blocks only once the OS reports it reached', () {
      final p = base.copyWith(usageLimitEnabled: true, usageLimitMinutes: 30);
      expect(p.isBlockingAt(noon), false);
      expect(p.isBlockingAt(noon, limitReachedToday: true), true);
    });

    test('a limit report is ignored when the limit rule is off', () {
      final p = scheduled(base);
      expect(p.isBlockingAt(evening, limitReachedToday: true), false);
    });

    test('schedule + tasks: done tasks do not unblock inside the window', () {
      final p = scheduled(
        base,
      ).copyWith(taskModeEnabled: true, tasks: doneTask);
      expect(p.isBlockingAt(noon), true);
      expect(p.isBlockingAt(evening), false);
    });

    test('schedule + tasks: pending tasks block outside the window too', () {
      final p = scheduled(
        base,
      ).copyWith(taskModeEnabled: true, tasks: pendingTask);
      expect(p.isBlockingAt(evening), true);
    });

    test('schedule + limit: a reached limit blocks after the window ends', () {
      final p = scheduled(
        base,
      ).copyWith(usageLimitEnabled: true, usageLimitMinutes: 30);
      expect(p.isBlockingAt(evening), false);
      expect(p.isBlockingAt(evening, limitReachedToday: true), true);
    });
  });

  group('copyWith', () {
    const full = BlockerProfile(
      id: 'p',
      name: 'P',
      scheduleStartHour: 9,
      scheduleStartMinute: 15,
      scheduleEndHour: 17,
      scheduleEndMinute: 45,
      usageLimitMinutes: 30,
      tasksLastResetDate: '2026-11-17',
      shieldActivatedAt: '2026-11-17T08:00:00.000',
    );

    test('omitted arguments keep the current values', () {
      final copy = full.copyWith(name: 'Renamed');

      expect(copy.name, 'Renamed');
      expect(copy.scheduleStartHour, 9);
      expect(copy.scheduleEndMinute, 45);
      expect(copy.usageLimitMinutes, 30);
      expect(copy.tasksLastResetDate, '2026-11-17');
      expect(copy.shieldActivatedAt, '2026-11-17T08:00:00.000');
    });

    test('passing null clears a nullable field', () {
      final copy = full.copyWith(
        scheduleStartHour: null,
        scheduleStartMinute: null,
        scheduleEndHour: null,
        scheduleEndMinute: null,
        usageLimitMinutes: null,
        tasksLastResetDate: null,
        shieldActivatedAt: null,
      );

      expect(copy.scheduleStartHour, isNull);
      expect(copy.scheduleStartMinute, isNull);
      expect(copy.scheduleEndHour, isNull);
      expect(copy.scheduleEndMinute, isNull);
      expect(copy.usageLimitMinutes, isNull);
      expect(copy.tasksLastResetDate, isNull);
      expect(copy.shieldActivatedAt, isNull);
    });

    test('nullable fields can be replaced', () {
      final copy = full.copyWith(usageLimitMinutes: 90, shieldActivatedAt: 'x');

      expect(copy.usageLimitMinutes, 90);
      expect(copy.shieldActivatedAt, 'x');
    });
  });
}
