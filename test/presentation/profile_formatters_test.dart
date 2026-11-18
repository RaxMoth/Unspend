import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/features/app_blocker/domain/entities/blocker_profile.dart';
import 'package:unspend/features/app_blocker/presentation/profile_formatters.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await S.setLocale('en');
  });

  group('formatDurationMinutes', () {
    test('minutes only', () => expect(formatDurationMinutes(45), '45 min'));
    test('whole hours', () => expect(formatDurationMinutes(120), '2 h'));
    test('hours and minutes', () {
      expect(formatDurationMinutes(90), '1 h 30 min');
      expect(formatDurationMinutes(1439), '23 h 59 min');
    });
  });

  test('formatMinuteOfDay pads to HH:mm', () {
    expect(formatMinuteOfDay(0), '00:00');
    expect(formatMinuteOfDay(9 * 60 + 5), '09:05');
    expect(formatMinuteOfDay(23 * 60 + 59), '23:59');
  });

  group('subtitle', () {
    test('prompts for apps when none are selected', () {
      const p = BlockerProfile(id: 'p', name: 'P');
      expect(p.subtitle(S.current), 'No apps selected');
    });

    test('manual profile shows the app count and "Manual"', () {
      const p = BlockerProfile(
        id: 'p',
        name: 'P',
        hasAppsSelected: true,
        appCount: 4,
      );
      expect(p.subtitle(S.current), '4 apps · Manual');
    });

    test('lists every enabled rule', () {
      const p = BlockerProfile(
        id: 'p',
        name: 'P',
        hasAppsSelected: true,
        appCount: 2,
        scheduleEnabled: true,
        scheduleStartHour: 22,
        scheduleStartMinute: 30,
        scheduleEndHour: 6,
        scheduleEndMinute: 0,
        usageLimitEnabled: true,
        usageLimitMinutes: 45,
        taskModeEnabled: true,
        tasks: [
          BlockerTask(id: '1', title: 'a', isDone: true),
          BlockerTask(id: '2', title: 'b'),
        ],
      );
      expect(
        p.subtitle(S.current),
        '2 apps · 22:30–06:00 · 45 min limit · 1/2 tasks',
      );
    });

    test('follows the active language', () async {
      await S.setLocale('de');
      const p = BlockerProfile(id: 'p', name: 'P');
      expect(p.subtitle(S.current), isNot('No apps selected'));
      expect(p.subtitle(S.current), isNotEmpty);
    });
  });

  group('requirementReason', () {
    final noon = DateTime(2026, 11, 17, 12);
    final evening = DateTime(2026, 11, 17, 20);

    const scheduledWithTasks = BlockerProfile(
      id: 'p',
      name: 'P',
      isActive: true,
      scheduleEnabled: true,
      scheduleStartHour: 9,
      scheduleStartMinute: 0,
      scheduleEndHour: 17,
      scheduleEndMinute: 0,
      taskModeEnabled: true,
      tasks: [
        BlockerTask(id: '1', title: 'a'),
        BlockerTask(id: '2', title: 'b'),
      ],
    );

    test('is empty for an inactive profile', () {
      const p = BlockerProfile(id: 'p', name: 'P');
      expect(p.requirementReason(S.current, noon), '');
    });

    test('manual mode explains how to unlock', () {
      const p = BlockerProfile(id: 'p', name: 'P', isActive: true);
      expect(
        p.requirementReason(S.current, noon),
        'Manual mode — deactivate to unlock',
      );
    });

    test('joins every reason that currently applies', () {
      expect(
        scheduledWithTasks.requirementReason(S.current, noon),
        'Inside schedule window · 2 tasks remaining',
      );
      expect(
        scheduledWithTasks.requirementReason(S.current, evening),
        '2 tasks remaining',
      );
    });

    test('mentions a reached usage limit', () {
      const p = BlockerProfile(
        id: 'p',
        name: 'P',
        isActive: true,
        usageLimitEnabled: true,
        usageLimitMinutes: 30,
      );
      expect(
        p.requirementReason(S.current, noon, limitReachedToday: true),
        'Daily limit reached',
      );
    });

    test('says so when nothing is blocking', () {
      const p = BlockerProfile(
        id: 'p',
        name: 'P',
        isActive: true,
        usageLimitEnabled: true,
        usageLimitMinutes: 30,
      );
      expect(
        p.requirementReason(S.current, noon),
        'All requirements met — apps accessible',
      );
    });
  });
}
