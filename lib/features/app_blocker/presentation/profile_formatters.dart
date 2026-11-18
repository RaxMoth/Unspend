import 'package:unspend/core/constants/strings.dart';

import '../domain/entities/blocker_profile.dart';

/// Formats a duration in minutes as `45 min`, `2 h` or `1 h 30 min`.
/// "h" and "min" are understood in every language the app ships in.
String formatDurationMinutes(int totalMinutes) {
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}

/// Formats a minute-of-day as `HH:mm`.
String formatMinuteOfDay(int minuteOfDay) {
  final h = (minuteOfDay ~/ 60).toString().padLeft(2, '0');
  final m = (minuteOfDay % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// User-facing text derived from a [BlockerProfile]. Kept out of the entity
/// so the domain layer does not depend on localization.
extension BlockerProfileText on BlockerProfile {
  /// One-line summary shown on the profile card.
  String subtitle(S s) {
    if (!hasAppsSelected) return s.noAppsSelected;
    final parts = <String>[s.subtitleApps(appCount)];

    if (hasSchedule) {
      parts.add(
        s.subtitleScheduleRange(
          formatMinuteOfDay(scheduleStartMinuteOfDay!),
          formatMinuteOfDay(scheduleEndMinuteOfDay!),
        ),
      );
    }
    if (usageLimitEnabled && usageLimitMinutes != null) {
      parts.add(
        s.subtitleUsageLimit(formatDurationMinutes(usageLimitMinutes!)),
      );
    }
    if (taskModeEnabled) {
      parts.add(s.subtitleTasks(doneTaskCount, tasks.length));
    }
    if (isManualOnly) parts.add(s.subtitleManual);

    return parts.join(' · ');
  }

  /// Why the profile is (or is not) blocking right now.
  String requirementReason(
    S s,
    DateTime now, {
    bool limitReachedToday = false,
  }) {
    if (!isActive) return '';
    if (isManualOnly) return s.reasonManualMode;

    final reasons = <String>[
      if (isInsideScheduleWindowAt(now)) s.reasonInsideSchedule,
      if (hasPendingTasks) s.reasonTasksRemaining(pendingTaskCount),
      if (usageLimitEnabled && limitReachedToday) s.reasonLimitReached,
    ];
    return reasons.isEmpty ? s.reasonAllMet : reasons.join(' · ');
  }
}
