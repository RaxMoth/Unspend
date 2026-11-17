import 'package:flutter_test/flutter_test.dart';
import 'package:unspend/features/app_blocker/domain/shield_policy.dart';

int _m(int hour, [int minute = 0]) => hour * 60 + minute;

void main() {
  group('ShieldPolicy.isInsideWindow', () {
    test('same-day window is half-open [start, end)', () {
      bool inside(int minute) => ShieldPolicy.isInsideWindow(
        minuteOfDay: minute,
        startMinute: _m(9),
        endMinute: _m(17),
      );

      expect(inside(_m(8, 59)), isFalse);
      expect(inside(_m(9)), isTrue);
      expect(inside(_m(12, 30)), isTrue);
      expect(inside(_m(16, 59)), isTrue);
      expect(inside(_m(17)), isFalse);
      expect(inside(_m(23, 59)), isFalse);
    });

    test('overnight window wraps past midnight', () {
      bool inside(int minute) => ShieldPolicy.isInsideWindow(
        minuteOfDay: minute,
        startMinute: _m(22),
        endMinute: _m(6),
      );

      expect(inside(_m(21, 59)), isFalse);
      expect(inside(_m(22)), isTrue);
      expect(inside(_m(23, 59)), isTrue);
      expect(inside(0), isTrue);
      expect(inside(_m(5, 59)), isTrue);
      expect(inside(_m(6)), isFalse);
      expect(inside(_m(12)), isFalse);
    });

    test('window ending exactly at midnight', () {
      bool inside(int minute) => ShieldPolicy.isInsideWindow(
        minuteOfDay: minute,
        startMinute: _m(20),
        endMinute: 0,
      );

      expect(inside(_m(19, 59)), isFalse);
      expect(inside(_m(20)), isTrue);
      expect(inside(_m(23, 59)), isTrue);
      expect(inside(0), isFalse);
    });

    test('empty window (start == end) contains nothing', () {
      for (final minute in [0, _m(9), _m(9, 1), _m(23, 59)]) {
        expect(
          ShieldPolicy.isInsideWindow(
            minuteOfDay: minute,
            startMinute: _m(9),
            endMinute: _m(9),
          ),
          isFalse,
        );
      }
    });
  });

  group('ShieldPolicy schedule validation', () {
    int length(int start, int end) =>
        ShieldPolicy.windowLengthMinutes(startMinute: start, endMinute: end);
    bool valid(int start, int end) =>
        ShieldPolicy.isValidSchedule(startMinute: start, endMinute: end);

    test('window length counts across midnight', () {
      expect(length(_m(9), _m(17)), 8 * 60);
      expect(length(_m(22), _m(6)), 8 * 60);
      expect(length(_m(9), _m(9)), 0);
      expect(length(_m(9), _m(8, 59)), 24 * 60 - 1);
    });

    test('rejects windows shorter than 15 minutes', () {
      expect(valid(_m(9), _m(9)), isFalse);
      expect(valid(_m(9), _m(9, 14)), isFalse);
      expect(valid(_m(9), _m(9, 15)), isTrue);
      expect(valid(_m(23, 50), _m(0, 4)), isFalse);
      expect(valid(_m(23, 50), _m(0, 5)), isTrue);
      expect(valid(_m(22), _m(6)), isTrue);
    });
  });

  group('ShieldPolicy.shouldShield', () {
    bool shield({
      bool manualOnly = false,
      bool insideScheduleWindow = false,
      bool tasksPending = false,
      bool limitReachedToday = false,
    }) => ShieldPolicy.shouldShield(
      manualOnly: manualOnly,
      insideScheduleWindow: insideScheduleWindow,
      tasksPending: tasksPending,
      limitReachedToday: limitReachedToday,
    );

    test('nothing demanding a block means no shield', () {
      expect(shield(), isFalse);
    });

    test('each rule alone is enough to shield', () {
      expect(shield(manualOnly: true), isTrue);
      expect(shield(insideScheduleWindow: true), isTrue);
      expect(shield(tasksPending: true), isTrue);
      expect(shield(limitReachedToday: true), isTrue);
    });

    test('stacked rules: one satisfied rule does not lift the others', () {
      // Tasks done, but still inside the schedule window.
      expect(shield(insideScheduleWindow: true, tasksPending: false), isTrue);
      // Schedule over, but the usage limit was reached.
      expect(
        shield(insideScheduleWindow: false, limitReachedToday: true),
        isTrue,
      );
      // Limit not reached, but tasks are pending.
      expect(shield(tasksPending: true, limitReachedToday: false), isTrue);
    });
  });
}
