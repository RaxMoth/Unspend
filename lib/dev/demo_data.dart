import 'package:shared_preferences/shared_preferences.dart';
import 'package:unspend/core/storage_keys.dart';
import 'package:unspend/core/time/day_key.dart';
import 'package:unspend/features/app_blocker/data/datasources/fake_screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/data/datasources/screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/data/repositories/profiles_repository.dart';
import 'package:unspend/features/app_blocker/domain/entities/blocker_profile.dart';

/// Sample profiles for the development entrypoint: one of every kind, so
/// every card and state is on screen without setting anything up. Also a
/// quick way to App Store screenshots.
///
/// Only `main_dev.dart` imports this; it is not part of the shipped app.
List<BlockerProfile> demoProfiles(DateTime now) => [
  BlockerProfile(
    id: 'demo-social',
    name: 'Social media',
    iconLabel: 'Social',
    hasAppsSelected: true,
    appCount: 12,
    scheduleEnabled: true,
    scheduleStartHour: 9,
    scheduleStartMinute: 0,
    scheduleEndHour: 17,
    scheduleEndMinute: 30,
    taskModeEnabled: true,
    tasks: const [
      BlockerTask(id: 'demo-task-1', title: 'Read twenty pages', isDone: true),
      BlockerTask(id: 'demo-task-2', title: 'Go for a run'),
    ],
    isActive: true,
    shieldActivatedAt: now.subtract(const Duration(hours: 2)).toIso8601String(),
    tasksLastResetDate: dayKey(now),
  ),
  BlockerProfile(
    id: 'demo-video',
    name: 'Video',
    colorValue: 0xFF1E88E5,
    iconLabel: 'Video',
    hasAppsSelected: true,
    appCount: 4,
    usageLimitEnabled: true,
    usageLimitMinutes: 45,
    isActive: true,
    shieldActivatedAt: now.subtract(const Duration(hours: 5)).toIso8601String(),
    tasksLastResetDate: dayKey(now),
  ),
  BlockerProfile(
    id: 'demo-games',
    name: 'Games',
    colorValue: 0xFF43A047,
    iconLabel: 'Games',
    hasAppsSelected: true,
    appCount: 3,
    tasksLastResetDate: dayKey(now),
  ),
];

/// Stores [demoProfiles] unless profiles exist already, and marks the
/// introduction as seen.
Future<void> seedDemoData(SharedPreferences prefs, DateTime now) async {
  final repository = ProfilesRepository(prefs);
  if ((await repository.load()).isEmpty) {
    await repository.save(demoProfiles(now));
  }
  await prefs.setBool(PrefKeys.onboardingSeen, true);
}

/// Tells the fake Screen Time about the stored profiles — their selected
/// apps and which of them are active — as the real one would remember them
/// across launches.
Future<void> restoreInto(
  FakeScreenTimeDatasource screenTime,
  SharedPreferences prefs,
) async {
  for (final profile in await ProfilesRepository(prefs).load()) {
    if (profile.hasAppsSelected) {
      screenTime.selections[profile.id] = profile.appCount;
    }
    if (profile.isActive) {
      screenTime.active[profile.id] = ActivationRequest.fromProfile(profile);
    }
  }
}
