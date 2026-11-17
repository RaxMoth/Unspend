/// Pure rule evaluation for a blocking profile.
///
/// This is the display-side mirror of `ios/Shared/Sources/ShieldCore/ShieldPolicy.swift`,
/// which is what actually enforces the block. Keep the two in sync: a profile
/// is shielded when ANY of its enabled rules says "block".
class ShieldPolicy {
  const ShieldPolicy._();

  static const minutesPerDay = 24 * 60;

  /// DeviceActivity rejects monitoring intervals shorter than this.
  static const minScheduleMinutes = 15;

  /// Whether [minuteOfDay] (0–1439) falls inside the half-open window
  /// `[startMinute, endMinute)`. Windows that cross midnight (22:00–06:00)
  /// are supported; an empty window (start == end) contains nothing.
  static bool isInsideWindow({
    required int minuteOfDay,
    required int startMinute,
    required int endMinute,
  }) {
    if (startMinute == endMinute) return false;
    if (startMinute < endMinute) {
      return minuteOfDay >= startMinute && minuteOfDay < endMinute;
    }
    return minuteOfDay >= startMinute || minuteOfDay < endMinute;
  }

  /// Length of the window in minutes, counting across midnight if needed.
  static int windowLengthMinutes({
    required int startMinute,
    required int endMinute,
  }) => (endMinute - startMinute) % minutesPerDay;

  /// A schedule the OS will accept: at least [minScheduleMinutes] long.
  static bool isValidSchedule({
    required int startMinute,
    required int endMinute,
  }) =>
      windowLengthMinutes(startMinute: startMinute, endMinute: endMinute) >=
      minScheduleMinutes;

  /// The rule itself. Each argument is already "is this rule enabled AND
  /// currently demanding a block", so disabled rules pass `false`.
  static bool shouldShield({
    required bool manualOnly,
    required bool insideScheduleWindow,
    required bool tasksPending,
    required bool limitReachedToday,
  }) => manualOnly || insideScheduleWindow || tasksPending || limitReachedToday;
}
