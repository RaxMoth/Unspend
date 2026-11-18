import 'package:flutter/material.dart';

import '../shield_policy.dart';

// ── Task entity ────────────────────────────────────────────────────────────

/// A single to-do item that must be completed before apps are unblocked.
class BlockerTask {
  final String id;
  final String title;
  final bool isDone;

  const BlockerTask({
    required this.id,
    required this.title,
    this.isDone = false,
  });

  BlockerTask copyWith({String? id, String? title, bool? isDone}) =>
      BlockerTask(
        id: id ?? this.id,
        title: title ?? this.title,
        isDone: isDone ?? this.isDone,
      );

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'isDone': isDone};

  factory BlockerTask.fromJson(Map<String, dynamic> j) => BlockerTask(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    isDone: j['isDone'] as bool? ?? false,
  );
}

// ── Helpers ────────────────────────────────────────────────────────────────

/// Pre-defined accent colours a user can assign to a profile.
///
/// [name] is a stable identifier, not display text; the UI localizes it.
class ProfileColor {
  final String name;
  final Color color;
  const ProfileColor(this.name, this.color);

  static const List<ProfileColor> palette = [
    ProfileColor('Red', Color(0xFFE53935)),
    ProfileColor('Orange', Color(0xFFFF9800)),
    ProfileColor('Amber', Color(0xFFFFC107)),
    ProfileColor('Green', Color(0xFF43A047)),
    ProfileColor('Teal', Color(0xFF00897B)),
    ProfileColor('Blue', Color(0xFF1E88E5)),
    ProfileColor('Indigo', Color(0xFF5C6BC0)),
    ProfileColor('Purple', Color(0xFF8E24AA)),
    ProfileColor('Pink', Color(0xFFD81B60)),
  ];
}

/// Pre-defined icons a user can assign to a profile.
///
/// [label] is the value persisted in the profile JSON, not display text.
class ProfileIcon {
  final String label;
  final IconData icon;
  const ProfileIcon(this.label, this.icon);

  static const List<ProfileIcon> options = [
    ProfileIcon('Social', Icons.people_alt_rounded),
    ProfileIcon('Games', Icons.sports_esports_rounded),
    ProfileIcon('Video', Icons.play_circle_rounded),
    ProfileIcon('News', Icons.article_rounded),
    ProfileIcon('Shopping', Icons.shopping_bag_rounded),
    ProfileIcon('Chat', Icons.chat_bubble_rounded),
    ProfileIcon('Music', Icons.music_note_rounded),
    ProfileIcon('Photos', Icons.photo_library_rounded),
    ProfileIcon('Work', Icons.work_rounded),
    ProfileIcon('Custom', Icons.apps_rounded),
  ];

  static ProfileIcon fromLabel(String label) =>
      options.firstWhere((o) => o.label == label, orElse: () => options.last);
}

/// Marks a `copyWith` argument as "not passed", so that passing `null`
/// explicitly can clear a nullable field.
const Object _unset = Object();

/// A single blocking profile – a named group of apps + its configuration.
///
/// Block rules stack; the apps are blocked while ANY enabled rule says so
/// (see [ShieldPolicy]):
///   • [scheduleEnabled] – blocked during a daily time window
///   • [usageLimitEnabled] – blocked once a daily screen-time budget is used
///   • [taskModeEnabled] – blocked until all [tasks] are done for the day
///   • none enabled – "manual": blocked from activation until deactivation
class BlockerProfile {
  final String id;
  final String name;
  final int colorValue;
  final String iconLabel;
  final bool isActive;

  // ── Schedule rule ────────────────────────────────────────────────────
  final bool scheduleEnabled;
  final int? scheduleStartHour;
  final int? scheduleStartMinute;
  final int? scheduleEndHour;
  final int? scheduleEndMinute;

  // ── Usage-limit rule ─────────────────────────────────────────────────
  final bool usageLimitEnabled;
  final int? usageLimitMinutes;

  // ── Task-mode rule ───────────────────────────────────────────────────
  final bool taskModeEnabled;
  final List<BlockerTask> tasks;

  /// Whether the user has picked apps for this profile.
  final bool hasAppsSelected;

  /// Number of apps selected (for display only).
  final int appCount;

  // ── Task reset tracking ──────────────────────────────────────────────
  /// Date (yyyy-MM-dd) when tasks were last reset. Used for daily reset.
  final String? tasksLastResetDate;

  // ── Stats tracking ───────────────────────────────────────────────────
  /// When the profile was last activated (ISO-8601). Null while inactive.
  final String? shieldActivatedAt;

  /// Cumulative minutes this profile has been active across all sessions.
  final int totalSavedMinutes;

  const BlockerProfile({
    required this.id,
    required this.name,
    this.colorValue = 0xFFE53935,
    this.iconLabel = 'Custom',
    this.isActive = false,
    this.scheduleEnabled = false,
    this.scheduleStartHour,
    this.scheduleStartMinute,
    this.scheduleEndHour,
    this.scheduleEndMinute,
    this.usageLimitEnabled = false,
    this.usageLimitMinutes,
    this.taskModeEnabled = false,
    this.tasks = const [],
    this.hasAppsSelected = false,
    this.appCount = 0,
    this.tasksLastResetDate,
    this.shieldActivatedAt,
    this.totalSavedMinutes = 0,
  });

  Color get color => Color(colorValue);
  ProfileIcon get profileIcon => ProfileIcon.fromLabel(iconLabel);

  /// Whether the profile is purely manual (no automated rules).
  bool get isManualOnly =>
      !scheduleEnabled && !usageLimitEnabled && !taskModeEnabled;

  /// Whether all tasks are completed (relevant when [taskModeEnabled]).
  bool get allTasksDone => tasks.isNotEmpty && tasks.every((t) => t.isDone);

  /// Number of remaining tasks.
  int get pendingTaskCount => tasks.where((t) => !t.isDone).length;

  /// Number of completed tasks.
  int get doneTaskCount => tasks.length - pendingTaskCount;

  /// Schedule start as minute-of-day (0–1439), or null when unset.
  int? get scheduleStartMinuteOfDay => scheduleStartHour == null
      ? null
      : scheduleStartHour! * 60 + (scheduleStartMinute ?? 0);

  /// Schedule end as minute-of-day (0–1439), or null when unset.
  int? get scheduleEndMinuteOfDay => scheduleEndHour == null
      ? null
      : scheduleEndHour! * 60 + (scheduleEndMinute ?? 0);

  /// Whether the schedule rule has a complete start and end time.
  bool get hasSchedule =>
      scheduleEnabled &&
      scheduleStartMinuteOfDay != null &&
      scheduleEndMinuteOfDay != null;

  /// Whether the schedule is one the OS will accept (see [ShieldPolicy]).
  bool get hasValidSchedule =>
      hasSchedule &&
      ShieldPolicy.isValidSchedule(
        startMinute: scheduleStartMinuteOfDay!,
        endMinute: scheduleEndMinuteOfDay!,
      );

  /// Is [minuteOfDay] (0–1439) inside this profile's schedule window?
  /// Handles overnight windows (e.g. 22:00–06:00).
  bool isMinuteInsideScheduleWindow(int minuteOfDay) =>
      hasSchedule &&
      ShieldPolicy.isInsideWindow(
        minuteOfDay: minuteOfDay,
        startMinute: scheduleStartMinuteOfDay!,
        endMinute: scheduleEndMinuteOfDay!,
      );

  /// Is [time] inside this profile's schedule window?
  bool isInsideScheduleWindowAt(DateTime time) =>
      isMinuteInsideScheduleWindow(time.hour * 60 + time.minute);

  /// Whether task mode is on and something is still left to do.
  bool get hasPendingTasks => taskModeEnabled && !allTasksDone;

  /// Whether this profile's apps should be blocked at [now].
  ///
  /// [limitReachedToday] comes from the OS (the usage limit is tracked
  /// natively); it defaults to false when unknown.
  bool isBlockingAt(DateTime now, {bool limitReachedToday = false}) =>
      isActive &&
      ShieldPolicy.shouldShield(
        manualOnly: isManualOnly,
        insideScheduleWindow: isInsideScheduleWindowAt(now),
        tasksPending: hasPendingTasks,
        limitReachedToday: usageLimitEnabled && limitReachedToday,
      );

  BlockerProfile copyWith({
    String? id,
    String? name,
    int? colorValue,
    String? iconLabel,
    bool? isActive,
    bool? scheduleEnabled,
    Object? scheduleStartHour = _unset,
    Object? scheduleStartMinute = _unset,
    Object? scheduleEndHour = _unset,
    Object? scheduleEndMinute = _unset,
    bool? usageLimitEnabled,
    Object? usageLimitMinutes = _unset,
    bool? taskModeEnabled,
    List<BlockerTask>? tasks,
    bool? hasAppsSelected,
    int? appCount,
    Object? tasksLastResetDate = _unset,
    Object? shieldActivatedAt = _unset,
    int? totalSavedMinutes,
  }) {
    T? pick<T>(Object? value, T? current) =>
        identical(value, _unset) ? current : value as T?;

    return BlockerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      iconLabel: iconLabel ?? this.iconLabel,
      isActive: isActive ?? this.isActive,
      scheduleEnabled: scheduleEnabled ?? this.scheduleEnabled,
      scheduleStartHour: pick(scheduleStartHour, this.scheduleStartHour),
      scheduleStartMinute: pick(scheduleStartMinute, this.scheduleStartMinute),
      scheduleEndHour: pick(scheduleEndHour, this.scheduleEndHour),
      scheduleEndMinute: pick(scheduleEndMinute, this.scheduleEndMinute),
      usageLimitEnabled: usageLimitEnabled ?? this.usageLimitEnabled,
      usageLimitMinutes: pick(usageLimitMinutes, this.usageLimitMinutes),
      taskModeEnabled: taskModeEnabled ?? this.taskModeEnabled,
      tasks: tasks ?? this.tasks,
      hasAppsSelected: hasAppsSelected ?? this.hasAppsSelected,
      appCount: appCount ?? this.appCount,
      tasksLastResetDate: pick(tasksLastResetDate, this.tasksLastResetDate),
      shieldActivatedAt: pick(shieldActivatedAt, this.shieldActivatedAt),
      totalSavedMinutes: totalSavedMinutes ?? this.totalSavedMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'iconLabel': iconLabel,
    'isActive': isActive,
    'scheduleEnabled': scheduleEnabled,
    'scheduleStartHour': scheduleStartHour,
    'scheduleStartMinute': scheduleStartMinute,
    'scheduleEndHour': scheduleEndHour,
    'scheduleEndMinute': scheduleEndMinute,
    'usageLimitEnabled': usageLimitEnabled,
    'usageLimitMinutes': usageLimitMinutes,
    'taskModeEnabled': taskModeEnabled,
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'hasAppsSelected': hasAppsSelected,
    'appCount': appCount,
    'tasksLastResetDate': tasksLastResetDate,
    'shieldActivatedAt': shieldActivatedAt,
    'totalSavedMinutes': totalSavedMinutes,
  };

  factory BlockerProfile.fromJson(Map<String, dynamic> j) => BlockerProfile(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? 'Untitled',
    colorValue: j['colorValue'] as int? ?? 0xFFE53935,
    iconLabel: j['iconLabel'] as String? ?? 'Custom',
    isActive: j['isActive'] as bool? ?? false,
    scheduleEnabled: j['scheduleEnabled'] as bool? ?? false,
    scheduleStartHour: (j['scheduleStartHour'] as int?)?.clamp(0, 23),
    scheduleStartMinute: (j['scheduleStartMinute'] as int?)?.clamp(0, 59),
    scheduleEndHour: (j['scheduleEndHour'] as int?)?.clamp(0, 23),
    scheduleEndMinute: (j['scheduleEndMinute'] as int?)?.clamp(0, 59),
    usageLimitEnabled: j['usageLimitEnabled'] as bool? ?? false,
    usageLimitMinutes: (j['usageLimitMinutes'] as int?)?.clamp(1, 1439),
    taskModeEnabled: j['taskModeEnabled'] as bool? ?? false,
    tasks:
        (j['tasks'] as List<dynamic>?)
            ?.map((e) => BlockerTask.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    hasAppsSelected: j['hasAppsSelected'] as bool? ?? false,
    appCount: (j['appCount'] as int? ?? 0).clamp(0, 999),
    tasksLastResetDate: j['tasksLastResetDate'] as String?,
    shieldActivatedAt: j['shieldActivatedAt'] as String?,
    totalSavedMinutes: (j['totalSavedMinutes'] as int? ?? 0).clamp(0, 999999),
  );
}
