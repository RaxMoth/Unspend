import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/time/day_key.dart';
import '../../data/datasources/method_channel_screen_time_datasource.dart';
import '../../data/datasources/screen_time_datasource.dart';
import '../../data/repositories/pin_repository.dart';
import '../../data/repositories/profiles_repository.dart';
import '../../domain/entities/blocker_profile.dart';
import 'authorization_provider.dart';
import 'device_mode_provider.dart';
import 'shield_activity_provider.dart';
import 'uninstall_protection_provider.dart';

/// The list of [BlockerProfile]s and every action on them.
final profilesProvider =
    AsyncNotifierProvider<ProfilesNotifier, List<BlockerProfile>>(
      ProfilesNotifier.new,
    );

/// What iOS last reported for each active profile, by profile id: whether
/// its apps are blocked right now and whether today's usage limit is used up.
/// Refreshed on every activation, task change and sync.
final shieldStatusProvider = StateProvider<Map<String, ShieldStatus>>(
  (ref) => const {},
);

/// Owns the profile list.
///
/// The OS enforces the blocks; this class keeps the stored profiles and the
/// OS in step. A profile only changes to active or inactive after the OS
/// confirmed the change, so the UI never claims a block that is not there.
///
/// All mutations run one after another (see [_serial]): each one reads the
/// current list, changes it and writes it back, and two of them interleaving
/// would lose an update.
class ProfilesNotifier extends AsyncNotifier<List<BlockerProfile>> {
  Future<void> _queue = Future.value();

  ScreenTimeDatasource get _screenTime =>
      ref.read(screenTimeDatasourceProvider);
  ProfilesRepository get _repository => ref.read(profilesRepositoryProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  Future<List<BlockerProfile>> build() async {
    final stored = await _repository.load();
    // An active profile always carries its activation time. One without it
    // is left over from an interrupted write; the next sync lifts whatever
    // block the OS may still hold for it.
    final profiles = [
      for (final profile in stored)
        if (profile.isActive && profile.shieldActivatedAt == null)
          profile.copyWith(isActive: false)
        else
          profile,
    ];
    if (profiles.any((p) => !stored.contains(p))) {
      await _repository.save(profiles);
    }
    return profiles;
  }

  // ── Plumbing ───────────────────────────────────────────────────────────

  List<BlockerProfile> get _profiles => state.valueOrNull ?? const [];

  BlockerProfile? _find(String id) =>
      _profiles.where((p) => p.id == id).firstOrNull;

  /// Runs [action] after every earlier mutation has finished, and only once
  /// the stored profiles are loaded.
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) async {
      await future;
      return action();
    });
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _write(List<BlockerProfile> profiles) async {
    state = AsyncData(profiles);
    try {
      await _repository.save(profiles);
    } catch (e) {
      debugPrint('[ProfilesNotifier] Saving profiles failed: $e');
    }
  }

  Future<void> _replace(BlockerProfile profile) => _write([
    for (final p in _profiles)
      if (p.id == profile.id) profile else p,
  ]);

  void _setStatus(String id, ShieldStatus? status) {
    final statuses = {...ref.read(shieldStatusProvider)};
    if (status == null) {
      statuses.remove(id);
    } else {
      statuses[id] = status;
    }
    ref.read(shieldStatusProvider.notifier).state = statuses;
  }

  String _newId() {
    final random = Random.secure().nextInt(1000000).toString().padLeft(6, '0');
    return '${_now().microsecondsSinceEpoch}_$random';
  }

  /// [profile] switched off, with the minutes of the session that just ended
  /// added to its total. A clock that moved backwards adds nothing.
  BlockerProfile _deactivated(BlockerProfile profile) {
    final activatedAt = DateTime.tryParse(profile.shieldActivatedAt ?? '');
    final minutes = activatedAt == null
        ? 0
        : max(0, _now().difference(activatedAt).inMinutes);
    return profile.copyWith(
      isActive: false,
      shieldActivatedAt: null,
      totalSavedMinutes: profile.totalSavedMinutes + minutes,
    );
  }

  // ── Create, edit, delete ───────────────────────────────────────────────

  /// Creates a profile and returns its id.
  Future<String> createProfile({required String name}) => _serial(() async {
    const palette = ProfileColor.palette;
    final profile = BlockerProfile(
      id: _newId(),
      name: name,
      colorValue: palette[_profiles.length % palette.length].color.toARGB32(),
    );
    await _write([..._profiles, profile]);
    return profile.id;
  });

  /// Saves the user-editable settings of [edited].
  ///
  /// While the profile is active only its name, colour and icon can change:
  /// loosening the rules of a running block would be a way around it.
  /// Everything the app itself maintains (active state, tasks, selected apps,
  /// statistics) is always taken from the stored profile, never from
  /// [edited], so a stale copy held by a screen cannot overwrite it.
  Future<void> updateProfile(BlockerProfile edited) => _serial(() async {
    final current = _find(edited.id);
    if (current == null) return;
    final cosmetic = current.copyWith(
      name: edited.name,
      colorValue: edited.colorValue,
      iconLabel: edited.iconLabel,
    );
    await _replace(
      current.isActive
          ? cosmetic
          : cosmetic.copyWith(
              scheduleEnabled: edited.scheduleEnabled,
              scheduleStartHour: edited.scheduleStartHour,
              scheduleStartMinute: edited.scheduleStartMinute,
              scheduleEndHour: edited.scheduleEndHour,
              scheduleEndMinute: edited.scheduleEndMinute,
              usageLimitEnabled: edited.usageLimitEnabled,
              usageLimitMinutes: edited.usageLimitMinutes,
              taskModeEnabled: edited.taskModeEnabled,
            ),
    );
  });

  /// Deletes a profile together with its app selection. Returns false, and
  /// changes nothing, while the profile is active: it has to be deactivated
  /// (PIN and cooldown) first.
  Future<bool> deleteProfile(String id) => _serial(() async {
    final profile = _find(id);
    if (profile == null || profile.isActive) return false;
    try {
      await _screenTime.deleteProfile(id);
    } on ScreenTimeException catch (e) {
      debugPrint('[ProfilesNotifier] Removing the app selection failed: $e');
    }
    await _write(_profiles.where((p) => p.id != id).toList());
    _setStatus(id, null);
    return true;
  });

  // ── Apps ───────────────────────────────────────────────────────────────

  /// Lets the user choose the apps of an inactive profile, asking for Screen
  /// Time access first if needed. Returns whether the selection changed.
  ///
  /// Throws [ScreenTimeException] with [ScreenTimeError.notAuthorized] when
  /// access is refused.
  Future<bool> pickAppsForProfile(
    String id, {
    required AppPickerLabels labels,
  }) => _serial(() async {
    final profile = _find(id);
    if (profile == null || profile.isActive) return false;

    // The iPhone's picker only opens with Screen Time access. Android's
    // needs none; there, access is asked for when it is needed to block.
    if (ref.read(appPlatformProvider) == AppPlatform.ios) {
      final approved = await ref
          .read(authorizationProvider.notifier)
          .ensureApproved();
      if (!approved) {
        throw const ScreenTimeException(ScreenTimeError.notAuthorized);
      }
    }

    final count = await _screenTime.pickApps(profileId: id, labels: labels);
    if (count == null) return false;
    // The picker was open for a while; apply the result to the latest copy.
    final latest = _find(id);
    if (latest == null) return false;
    await _replace(
      latest.copyWith(hasAppsSelected: count > 0, appCount: count),
    );
    return true;
  });

  // ── Activation ─────────────────────────────────────────────────────────

  /// Starts blocking according to the profile's rules.
  ///
  /// Throws [ScreenTimeException] when the profile cannot be activated; the
  /// profile then stays inactive.
  Future<void> activateProfile(String id) => _serial(() => _activate(id));

  /// Stops blocking. Throws [ScreenTimeException] when the OS refused; the
  /// profile then stays active.
  Future<void> deactivateProfile(String id) => _serial(() => _deactivate(id));

  Future<void> _activate(String id) async {
    final profile = _find(id);
    if (profile == null || profile.isActive) return;
    if (!profile.hasAppsSelected) {
      throw const ScreenTimeException(ScreenTimeError.noSelection);
    }
    if (profile.scheduleEnabled && !profile.hasValidSchedule) {
      throw const ScreenTimeException(ScreenTimeError.scheduleTooShort);
    }
    if (profile.usageLimitEnabled && profile.usageLimitMinutes == null) {
      throw const ScreenTimeException(
        ScreenTimeError.unknown,
        'The usage limit has no duration',
      );
    }
    if (profile.taskModeEnabled && profile.tasks.isEmpty) {
      throw const ScreenTimeException(ScreenTimeError.taskModeNeedsTasks);
    }

    // Task mode starts with every task open: the point is to do them now.
    final now = _now();
    final prepared = profile.copyWith(
      tasks: profile.taskModeEnabled
          ? [for (final task in profile.tasks) task.copyWith(isDone: false)]
          : profile.tasks,
      tasksLastResetDate: dayKey(now),
    );

    final status = await _screenTime.activate(
      ActivationRequest.fromProfile(prepared),
    );

    await _replace(
      prepared.copyWith(
        isActive: true,
        shieldActivatedAt: now.toIso8601String(),
      ),
    );
    _setStatus(id, status);
    await ref
        .read(shieldActivityProvider.notifier)
        .record(_profiles.where((p) => p.isActive).length);
  }

  Future<void> _deactivate(String id) async {
    final profile = _find(id);
    if (profile == null || !profile.isActive) return;
    await _screenTime.deactivate(id);
    await _replace(_deactivated(profile));
    _setStatus(id, null);
  }

  // ── Tasks ──────────────────────────────────────────────────────────────

  /// Adds a task. Ignored while the profile is active.
  Future<void> addTask(String profileId, String title) => _serial(() async {
    final profile = _find(profileId);
    if (profile == null || profile.isActive) return;
    await _replace(
      profile.copyWith(
        tasks: [
          ...profile.tasks,
          BlockerTask(id: _newId(), title: title),
        ],
      ),
    );
  });

  /// Removes a task. Ignored while the profile is active.
  Future<void> removeTask(String profileId, String taskId) => _serial(() async {
    final profile = _find(profileId);
    if (profile == null || profile.isActive) return;
    await _replace(
      profile.copyWith(
        tasks: profile.tasks.where((t) => t.id != taskId).toList(),
      ),
    );
  });

  /// Ticks or unticks a task. On an active task-mode profile, finishing the
  /// last task lifts the task block and reopening one puts it back.
  Future<void> toggleTask(String profileId, String taskId) => _serial(() async {
    await _resetTasksIfNewDay();
    final profile = _find(profileId);
    if (profile == null || !profile.tasks.any((t) => t.id == taskId)) return;

    final updated = profile.copyWith(
      tasks: [
        for (final task in profile.tasks)
          if (task.id == taskId) task.copyWith(isDone: !task.isDone) else task,
      ],
    );
    await _replace(updated);

    final enforced = updated.isActive && updated.taskModeEnabled;
    if (!enforced || updated.allTasksDone == profile.allTasksDone) return;
    try {
      _setStatus(
        profileId,
        await _screenTime.setTasksDone(profileId, done: updated.allTasksDone),
      );
    } on ScreenTimeException catch (e) {
      // The task state is saved; the next sync passes it on to the OS.
      debugPrint('[ProfilesNotifier] Updating the task block failed: $e');
    }
  });

  /// Tasks are daily: the first time the app looks at them on a new day,
  /// yesterday's ticks are cleared. (For active profiles the OS re-locks at
  /// midnight on its own; this keeps the list on screen in step.)
  Future<void> _resetTasksIfNewDay() async {
    final today = dayKey(_now());
    if (_profiles.every((p) => p.tasksLastResetDate == today)) return;
    await _write([
      for (final profile in _profiles)
        if (profile.tasksLastResetDate == today)
          profile
        else if (profile.tasksLastResetDate == null)
          // Never stamped (created before daily resets): keep its ticks.
          profile.copyWith(tasksLastResetDate: today)
        else
          profile.copyWith(
            tasks: [for (final t in profile.tasks) t.copyWith(isDone: false)],
            tasksLastResetDate: today,
          ),
    ]);
  }

  // ── Keeping in step with the OS ────────────────────────────────────────

  /// Brings the app and the OS back in line. Called when the app starts,
  /// returns to the foreground and passes midnight.
  ///
  /// Resets yesterday's tasks, has the OS re-evaluate every active profile
  /// (lifting blocks of profiles the app no longer knows as active), marks
  /// profiles the OS can no longer enforce as inactive and refreshes
  /// [shieldStatusProvider].
  Future<void> syncWithSystem() => _serial(() async {
    await _resetTasksIfNewDay();
    final active = _profiles.where((p) => p.isActive).toList();

    final Map<String, ShieldStatus> statuses;
    try {
      statuses = await _screenTime.sync([
        for (final profile in active)
          ActiveProfileState(
            profileId: profile.id,
            tasksDone: profile.taskModeEnabled && profile.allTasksDone,
          ),
      ]);
    } on ScreenTimeException catch (e) {
      debugPrint('[ProfilesNotifier] Sync failed: $e');
      return;
    }

    final lost = {
      for (final profile in active)
        if (!statuses.containsKey(profile.id)) profile.id,
    };
    if (lost.isNotEmpty) {
      await _write([
        for (final profile in _profiles)
          if (lost.contains(profile.id)) _deactivated(profile) else profile,
      ]);
    }
    ref.read(shieldStatusProvider.notifier).state = statuses;
  });

  // ── Reset ──────────────────────────────────────────────────────────────

  /// Lifts every block and deletes all profiles, the PIN and all settings.
  /// Screen Time access is given back too, so the app starts over as on a
  /// first launch — including the choice of who uses the phone.
  Future<void> deleteAllData() => _serial(() async {
    try {
      await _screenTime.resetAll([for (final p in _profiles) p.id]);
      await _screenTime.revokeAuthorization();
    } on ScreenTimeException catch (e) {
      debugPrint('[ProfilesNotifier] Clearing the OS side failed: $e');
    }
    await ref.read(sharedPreferencesProvider).clear();
    await ref.read(pinRepositoryProvider).clear();
    state = const AsyncData([]);
    ref.read(shieldStatusProvider.notifier).state = const {};
    ref.invalidate(shieldActivityProvider);
    ref.invalidate(deviceModeProvider);
    ref.invalidate(uninstallProtectionProvider);
    await ref.read(authorizationProvider.notifier).refresh();
  });
}
