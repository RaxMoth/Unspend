import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unspend/core/providers.dart';
import 'package:unspend/core/storage_keys.dart';
import 'package:unspend/features/app_blocker/data/datasources/fake_screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/data/datasources/method_channel_screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/data/datasources/screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/data/repositories/pin_repository.dart';
import 'package:unspend/features/app_blocker/data/repositories/profiles_repository.dart';
import 'package:unspend/features/app_blocker/domain/entities/blocker_profile.dart';
import 'package:unspend/features/app_blocker/presentation/providers/profiles_provider.dart';
import 'package:unspend/features/app_blocker/presentation/providers/shield_activity_provider.dart';
import 'package:unspend/features/app_blocker/presentation/providers/uninstall_protection_provider.dart';

const _labels = AppPickerLabels(
  title: 'Choose Apps',
  cancel: 'Cancel',
  save: 'Save',
  tooMany: 'Too many',
);

const _shielded = ShieldStatus(shielded: true, limitReachedToday: false);
const _open = ShieldStatus(shielded: false, limitReachedToday: false);

Matcher _throwsScreenTime(ScreenTimeError error) =>
    throwsA(isA<ScreenTimeException>().having((e) => e.error, 'error', error));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late FakeScreenTimeDatasource screenTime;
  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() {
    now = DateTime(2026, 11, 17, 12);
    screenTime = FakeScreenTimeDatasource(clock: () => now);
  });

  /// Starts the app's state on top of [stored] profiles.
  Future<ProfilesNotifier> start({
    List<BlockerProfile> stored = const [],
    bool waitForLoad = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      PrefKeys.profilesSchemaVersion: ProfilesRepository.currentSchemaVersion,
      if (stored.isNotEmpty)
        PrefKeys.profiles: jsonEncode([
          for (final profile in stored) profile.toJson(),
        ]),
    });
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => now),
        screenTimeDatasourceProvider.overrideWithValue(screenTime),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(profilesProvider.notifier);
    if (waitForLoad) await container.read(profilesProvider.future);
    return notifier;
  }

  List<BlockerProfile> profiles() =>
      container.read(profilesProvider).requireValue;
  BlockerProfile profile(String id) =>
      profiles().singleWhere((p) => p.id == id);
  ShieldStatus? status(String id) => container.read(shieldStatusProvider)[id];

  List<BlockerProfile> persisted() => [
    for (final json in jsonDecode(prefs.getString(PrefKeys.profiles)!) as List)
      BlockerProfile.fromJson(json as Map<String, dynamic>),
  ];

  /// A profile with apps picked and, optionally, rules and tasks.
  Future<String> ready(
    ProfilesNotifier notifier, {
    BlockerProfile Function(BlockerProfile profile)? rules,
    List<String> tasks = const [],
  }) async {
    final id = await notifier.createProfile(name: 'Focus');
    await notifier.pickAppsForProfile(id, labels: _labels);
    if (rules != null) await notifier.updateProfile(rules(profile(id)));
    for (final title in tasks) {
      await notifier.addTask(id, title);
    }
    screenTime.calls.clear();
    return id;
  }

  BlockerProfile schedule(BlockerProfile p, int startHour, int endHour) =>
      p.copyWith(
        scheduleEnabled: true,
        scheduleStartHour: startHour,
        scheduleStartMinute: 0,
        scheduleEndHour: endHour,
        scheduleEndMinute: 0,
      );

  BlockerProfile limit(BlockerProfile p, int minutes) =>
      p.copyWith(usageLimitEnabled: true, usageLimitMinutes: minutes);

  BlockerProfile taskMode(BlockerProfile p) =>
      p.copyWith(taskModeEnabled: true);

  String taskId(String profileId, String title) =>
      profile(profileId).tasks.singleWhere((t) => t.title == title).id;

  group('loading', () {
    test('starts with no profiles', () async {
      await start();

      expect(profiles(), isEmpty);
      expect(screenTime.calls, isEmpty, reason: 'loading must not prompt');
    });

    test('restores stored profiles', () async {
      await start(
        stored: const [
          BlockerProfile(id: 'a', name: 'Work'),
          BlockerProfile(id: 'b', name: 'Evening'),
        ],
      );

      expect(profiles().map((p) => p.name), ['Work', 'Evening']);
    });

    test(
      'an active profile without an activation time is switched off',
      () async {
        await start(
          stored: [
            const BlockerProfile(id: 'broken', name: 'Broken', isActive: true),
            BlockerProfile(
              id: 'fine',
              name: 'Fine',
              isActive: true,
              shieldActivatedAt: now.toIso8601String(),
            ),
          ],
        );

        expect(profile('broken').isActive, isFalse);
        expect(profile('fine').isActive, isTrue);
        expect(
          persisted().firstWhere((p) => p.id == 'broken').isActive,
          isFalse,
        );
      },
    );

    test(
      'a change requested while loading keeps the stored profiles',
      () async {
        final notifier = await start(
          stored: const [BlockerProfile(id: 'a', name: 'Stored')],
          waitForLoad: false,
        );

        await notifier.createProfile(name: 'New');

        expect(profiles().map((p) => p.name), ['Stored', 'New']);
        expect(persisted().map((p) => p.name), ['Stored', 'New']);
      },
    );
  });

  group('creating, editing and deleting', () {
    test('a new profile is saved and gets the next palette colour', () async {
      final notifier = await start();

      final first = await notifier.createProfile(name: 'One');
      final second = await notifier.createProfile(name: 'Two');

      expect(first, isNot(second));
      expect(
        profile(first).colorValue,
        ProfileColor.palette[0].color.toARGB32(),
      );
      expect(
        profile(second).colorValue,
        ProfileColor.palette[1].color.toARGB32(),
      );
      expect(persisted().map((p) => p.name), ['One', 'Two']);
    });

    test('rule settings of an inactive profile can be changed', () async {
      final notifier = await start();
      final id = await ready(notifier);

      await notifier.updateProfile(
        limit(schedule(profile(id), 9, 17), 45).copyWith(name: 'Work'),
      );

      final saved = persisted().single;
      expect(saved.name, 'Work');
      expect(saved.scheduleEnabled, isTrue);
      expect(saved.scheduleStartHour, 9);
      expect(saved.usageLimitMinutes, 45);
    });

    test(
      'an active profile only accepts a new name, colour and icon',
      () async {
        final notifier = await start();
        final id = await ready(notifier);
        await notifier.activateProfile(id);

        await notifier.updateProfile(
          schedule(profile(id), 1, 2).copyWith(
            name: 'Renamed',
            colorValue: 0xFF00897B,
            iconLabel: 'Work',
            usageLimitEnabled: true,
            usageLimitMinutes: 1,
            taskModeEnabled: true,
          ),
        );

        final saved = profile(id);
        expect(saved.name, 'Renamed');
        expect(saved.colorValue, 0xFF00897B);
        expect(saved.iconLabel, 'Work');
        expect(
          saved.isManualOnly,
          isTrue,
          reason: 'rules are locked while active',
        );
        expect(saved.isActive, isTrue);
      },
    );

    test('a stale copy cannot overwrite what the app maintains', () async {
      final notifier = await start();
      final id = await ready(notifier, tasks: ['Read']);
      final stale = profile(id);
      await notifier.addTask(id, 'Run');

      await notifier.updateProfile(
        stale.copyWith(
          name: 'Edited',
          isActive: true,
          appCount: 99,
          hasAppsSelected: false,
          totalSavedMinutes: 500,
        ),
      );

      final saved = profile(id);
      expect(saved.name, 'Edited');
      expect(saved.tasks.map((t) => t.title), ['Read', 'Run']);
      expect(saved.isActive, isFalse);
      expect(saved.appCount, 3);
      expect(saved.hasAppsSelected, isTrue);
      expect(saved.totalSavedMinutes, 0);
    });

    test('editing an unknown profile does nothing', () async {
      final notifier = await start();

      await notifier.updateProfile(
        const BlockerProfile(id: 'ghost', name: 'x'),
      );

      expect(profiles(), isEmpty);
    });

    test('deleting removes the profile and its app selection', () async {
      final notifier = await start();
      final id = await ready(notifier);

      expect(await notifier.deleteProfile(id), isTrue);

      expect(profiles(), isEmpty);
      expect(persisted(), isEmpty);
      expect(screenTime.calls, ['deleteProfile:$id']);
      expect(screenTime.selections, isEmpty);
    });

    test('an active profile cannot be deleted', () async {
      final notifier = await start();
      final id = await ready(notifier);
      await notifier.activateProfile(id);
      screenTime.calls.clear();

      expect(await notifier.deleteProfile(id), isFalse);

      expect(profile(id).isActive, isTrue);
      expect(screenTime.calls, isEmpty);
      expect(screenTime.isShielded(id), isTrue);
    });

    test('deleting still works when the OS side fails', () async {
      final notifier = await start();
      final id = await ready(notifier);
      screenTime.failNext = const ScreenTimeException(
        ScreenTimeError.unavailable,
      );

      expect(await notifier.deleteProfile(id), isTrue);
      expect(profiles(), isEmpty);
    });
  });

  group('picking apps', () {
    test('stores how many items were picked', () async {
      final notifier = await start();
      final id = await notifier.createProfile(name: 'Focus');
      screenTime.pickCount = 7;

      expect(await notifier.pickAppsForProfile(id, labels: _labels), isTrue);

      expect(profile(id).hasAppsSelected, isTrue);
      expect(profile(id).appCount, 7);
      expect(persisted().single.appCount, 7);
      expect(screenTime.lastPickerLabels, same(_labels));
    });

    test('asks for Screen Time access first when undecided', () async {
      screenTime.authStatus = ScreenTimeAuthStatus.notDetermined;
      final notifier = await start();
      final id = await notifier.createProfile(name: 'Focus');

      await notifier.pickAppsForProfile(id, labels: _labels);

      expect(screenTime.calls, [
        'requestAuthorization:individual',
        'pickApps:$id',
      ]);
    });

    test('does not open the picker when access is refused', () async {
      screenTime
        ..authStatus = ScreenTimeAuthStatus.notDetermined
        ..statusAfterRequest = ScreenTimeAuthStatus.denied;
      final notifier = await start();
      final id = await notifier.createProfile(name: 'Focus');

      await expectLater(
        notifier.pickAppsForProfile(id, labels: _labels),
        _throwsScreenTime(ScreenTimeError.notAuthorized),
      );

      expect(screenTime.calls, ['requestAuthorization:individual']);
      expect(profile(id).hasAppsSelected, isFalse);
    });

    test('cancelling the picker changes nothing', () async {
      final notifier = await start();
      final id = await ready(notifier);
      screenTime.pickCount = null;

      expect(await notifier.pickAppsForProfile(id, labels: _labels), isFalse);

      expect(profile(id).appCount, 3);
    });

    test('the apps of an active profile cannot be changed', () async {
      final notifier = await start();
      final id = await ready(notifier);
      await notifier.activateProfile(id);
      screenTime.calls.clear();

      expect(await notifier.pickAppsForProfile(id, labels: _labels), isFalse);

      expect(screenTime.calls, isEmpty);
    });
  });

  group('activating', () {
    test('a manual profile blocks straight away', () async {
      final notifier = await start();
      final id = await ready(notifier);

      await notifier.activateProfile(id);

      expect(screenTime.calls, ['activate:$id']);
      expect(
        screenTime.active[id],
        ActivationRequest(profileId: id, name: 'Focus'),
      );
      expect(profile(id).isActive, isTrue);
      expect(profile(id).shieldActivatedAt, now.toIso8601String());
      expect(persisted().single.isActive, isTrue);
      expect(status(id), _shielded);
    });

    test('a schedule blocks only inside its window', () async {
      final notifier = await start();
      final inside = await ready(notifier, rules: (p) => schedule(p, 9, 17));
      final outside = await ready(notifier, rules: (p) => schedule(p, 14, 16));

      await notifier.activateProfile(inside);
      await notifier.activateProfile(outside);

      expect(status(inside), _shielded);
      expect(status(outside), _open, reason: 'armed, waiting for 14:00');
      expect(profile(outside).isActive, isTrue);
      expect(screenTime.active[outside]!.scheduleStartMinute, 14 * 60);
      expect(screenTime.active[outside]!.scheduleEndMinute, 16 * 60);
    });

    test('an overnight schedule blocks across midnight', () async {
      now = DateTime(2026, 11, 17, 23, 30);
      final notifier = await start();
      final id = await ready(notifier, rules: (p) => schedule(p, 22, 6));

      await notifier.activateProfile(id);
      expect(status(id), _shielded);

      now = DateTime(2026, 11, 18, 5, 59);
      await notifier.syncWithSystem();
      expect(status(id), _shielded);

      now = DateTime(2026, 11, 18, 6);
      await notifier.syncWithSystem();
      expect(status(id), _open);
      expect(profile(id).isActive, isTrue);
    });

    test('a usage limit does not block until it is used up', () async {
      final notifier = await start();
      final id = await ready(notifier, rules: (p) => limit(p, 30));

      await notifier.activateProfile(id);
      expect(status(id), _open);
      expect(screenTime.active[id]!.usageLimitMinutes, 30);

      screenTime.reachLimit(id);
      await notifier.syncWithSystem();
      expect(
        status(id),
        const ShieldStatus(shielded: true, limitReachedToday: true),
      );

      now = now.add(const Duration(days: 1));
      await notifier.syncWithSystem();
      expect(status(id), _open, reason: 'the limit is per day');
    });

    test('task mode starts with every task open and blocks', () async {
      final notifier = await start();
      final id = await ready(notifier, rules: taskMode, tasks: ['Read', 'Run']);
      await notifier.toggleTask(id, taskId(id, 'Read'));

      await notifier.activateProfile(id);

      expect(profile(id).tasks.every((t) => !t.isDone), isTrue);
      expect(profile(id).tasksLastResetDate, '2026-11-17');
      expect(screenTime.active[id]!.taskModeEnabled, isTrue);
      expect(screenTime.active[id]!.tasksDone, isFalse);
      expect(status(id), _shielded);
    });

    test('all three rules are sent together', () async {
      final notifier = await start();
      final id = await ready(
        notifier,
        rules: (p) => taskMode(limit(schedule(p, 22, 6), 90)),
        tasks: ['Read'],
      );

      await notifier.activateProfile(id);

      expect(
        screenTime.active[id],
        ActivationRequest(
          profileId: id,
          name: 'Focus',
          scheduleStartMinute: 22 * 60,
          scheduleEndMinute: 6 * 60,
          usageLimitMinutes: 90,
          taskModeEnabled: true,
        ),
      );
    });

    test('rules that are switched off are not sent', () async {
      final notifier = await start();
      final id = await ready(
        notifier,
        rules: (p) => limit(
          schedule(p, 9, 17),
          30,
        ).copyWith(scheduleEnabled: false, usageLimitEnabled: false),
      );

      await notifier.activateProfile(id);

      expect(
        screenTime.active[id],
        ActivationRequest(profileId: id, name: 'Focus'),
      );
    });

    test('is refused without selected apps', () async {
      final notifier = await start();
      final id = await notifier.createProfile(name: 'Empty');

      await expectLater(
        notifier.activateProfile(id),
        _throwsScreenTime(ScreenTimeError.noSelection),
      );
      expect(screenTime.calls, isEmpty);
      expect(profile(id).isActive, isFalse);
    });

    test('is refused when the schedule is shorter than 15 minutes', () async {
      final notifier = await start();
      final id = await ready(
        notifier,
        rules: (p) => schedule(p, 9, 9).copyWith(scheduleEndMinute: 10),
      );

      await expectLater(
        notifier.activateProfile(id),
        _throwsScreenTime(ScreenTimeError.scheduleTooShort),
      );
      expect(screenTime.calls, isEmpty);
    });

    test('is refused in task mode without tasks', () async {
      final notifier = await start();
      final id = await ready(notifier, rules: taskMode);

      await expectLater(
        notifier.activateProfile(id),
        _throwsScreenTime(ScreenTimeError.taskModeNeedsTasks),
      );
      expect(screenTime.calls, isEmpty);
    });

    test('is refused when the usage limit has no duration', () async {
      final notifier = await start();
      final id = await ready(
        notifier,
        rules: (p) =>
            p.copyWith(usageLimitEnabled: true, usageLimitMinutes: null),
      );

      await expectLater(
        notifier.activateProfile(id),
        _throwsScreenTime(ScreenTimeError.unknown),
      );
      expect(screenTime.calls, isEmpty);
    });

    for (final error in [
      ScreenTimeError.notAuthorized,
      ScreenTimeError.tooManyActivities,
      ScreenTimeError.tooManyApps,
    ]) {
      test('stays inactive when the OS answers ${error.name}', () async {
        final notifier = await start();
        final id = await ready(notifier, rules: taskMode, tasks: ['Read']);
        await notifier.toggleTask(id, taskId(id, 'Read'));
        screenTime.failNext = ScreenTimeException(error);

        await expectLater(
          notifier.activateProfile(id),
          _throwsScreenTime(error),
        );

        expect(profile(id).isActive, isFalse);
        expect(profile(id).shieldActivatedAt, isNull);
        expect(
          profile(id).tasks.single.isDone,
          isTrue,
          reason: 'nothing changed',
        );
        expect(persisted().single.isActive, isFalse);
        expect(status(id), isNull);
      });
    }

    test('activating twice sends one request', () async {
      final notifier = await start();
      final id = await ready(notifier);

      await Future.wait([
        notifier.activateProfile(id),
        notifier.activateProfile(id),
      ]);

      expect(screenTime.calls, ['activate:$id']);
    });

    test('records the day\'s peak of active profiles', () async {
      final notifier = await start();
      final first = await ready(notifier);
      final second = await ready(notifier);

      await notifier.activateProfile(first);
      await notifier.activateProfile(second);
      await notifier.deactivateProfile(first);

      expect(container.read(shieldActivityProvider), {'2026-11-17': 2});
    });
  });

  group('deactivating', () {
    test('lifts the block and adds the session to the total', () async {
      final notifier = await start();
      final id = await ready(notifier);
      await notifier.activateProfile(id);
      screenTime.calls.clear();
      now = now.add(const Duration(minutes: 90));

      await notifier.deactivateProfile(id);

      expect(screenTime.calls, ['deactivate:$id']);
      expect(screenTime.isShielded(id), isFalse);
      expect(profile(id).isActive, isFalse);
      expect(profile(id).shieldActivatedAt, isNull);
      expect(profile(id).totalSavedMinutes, 90);
      expect(persisted().single.isActive, isFalse);
      expect(status(id), isNull);
    });

    test('a clock that moved backwards adds no minutes', () async {
      final notifier = await start();
      final id = await ready(notifier);
      await notifier.activateProfile(id);
      now = now.subtract(const Duration(hours: 3));

      await notifier.deactivateProfile(id);

      expect(profile(id).totalSavedMinutes, 0);
    });

    test('the profile stays active when the OS refuses', () async {
      final notifier = await start();
      final id = await ready(notifier);
      await notifier.activateProfile(id);
      screenTime.failNext = const ScreenTimeException(ScreenTimeError.unknown);

      await expectLater(
        notifier.deactivateProfile(id),
        _throwsScreenTime(ScreenTimeError.unknown),
      );

      expect(profile(id).isActive, isTrue);
      expect(status(id), _shielded);
    });

    test('deactivating an inactive profile does nothing', () async {
      final notifier = await start();
      final id = await ready(notifier);

      await notifier.deactivateProfile(id);

      expect(screenTime.calls, isEmpty);
    });

    test('one of two overlapping profiles keeps blocking', () async {
      final notifier = await start();
      final first = await ready(notifier);
      final second = await ready(notifier);
      await notifier.activateProfile(first);
      await notifier.activateProfile(second);

      await notifier.deactivateProfile(first);

      expect(screenTime.isShielded(first), isFalse);
      expect(screenTime.isShielded(second), isTrue);
      expect(profile(second).isActive, isTrue);
    });
  });

  group('tasks', () {
    test('can be added and removed while inactive', () async {
      final notifier = await start();
      final id = await ready(notifier, tasks: ['Read', 'Run']);

      await notifier.removeTask(id, taskId(id, 'Read'));

      expect(profile(id).tasks.map((t) => t.title), ['Run']);
      expect(persisted().single.tasks.map((t) => t.title), ['Run']);
    });

    test('cannot be added or removed while active', () async {
      final notifier = await start();
      final id = await ready(notifier, rules: taskMode, tasks: ['Read']);
      await notifier.activateProfile(id);

      await notifier.addTask(id, 'Easy one');
      await notifier.removeTask(id, taskId(id, 'Read'));

      expect(profile(id).tasks.map((t) => t.title), ['Read']);
    });

    test(
      'ticking a task of an inactive profile does not involve the OS',
      () async {
        final notifier = await start();
        final id = await ready(notifier, rules: taskMode, tasks: ['Read']);

        await notifier.toggleTask(id, taskId(id, 'Read'));

        expect(profile(id).tasks.single.isDone, isTrue);
        expect(screenTime.calls, isEmpty);
      },
    );

    test(
      'finishing the last task lifts the block, reopening restores it',
      () async {
        final notifier = await start();
        final id = await ready(
          notifier,
          rules: taskMode,
          tasks: ['Read', 'Run'],
        );
        await notifier.activateProfile(id);
        screenTime.calls.clear();

        await notifier.toggleTask(id, taskId(id, 'Read'));
        expect(screenTime.calls, isEmpty, reason: 'one task is still open');
        expect(screenTime.isShielded(id), isTrue);

        await notifier.toggleTask(id, taskId(id, 'Run'));
        expect(screenTime.calls, ['setTasksDone:$id:true']);
        expect(status(id), _open);
        expect(
          profile(id).isActive,
          isTrue,
          reason: 'still armed for tomorrow',
        );

        await notifier.toggleTask(id, taskId(id, 'Run'));
        expect(screenTime.calls.last, 'setTasksDone:$id:false');
        expect(status(id), _shielded);
      },
    );

    test('finished tasks do not unblock inside the schedule window', () async {
      final notifier = await start();
      final id = await ready(
        notifier,
        rules: (p) => taskMode(schedule(p, 9, 17)),
        tasks: ['Read'],
      );
      await notifier.activateProfile(id);

      await notifier.toggleTask(id, taskId(id, 'Read'));
      expect(status(id), _shielded, reason: 'the schedule still applies');

      now = DateTime(2026, 11, 17, 18);
      await notifier.syncWithSystem();
      expect(status(id), _open);

      await notifier.toggleTask(id, taskId(id, 'Read'));
      expect(status(id), _shielded, reason: 'open tasks block after hours too');
    });

    test('finished tasks do not unblock a used-up limit', () async {
      final notifier = await start();
      final id = await ready(
        notifier,
        rules: (p) => taskMode(limit(p, 30)),
        tasks: ['Read'],
      );
      await notifier.activateProfile(id);
      screenTime.reachLimit(id);

      await notifier.toggleTask(id, taskId(id, 'Read'));

      expect(
        status(id),
        const ShieldStatus(shielded: true, limitReachedToday: true),
      );
    });

    test(
      'a failed OS update keeps the tick and is repaired by the next sync',
      () async {
        final notifier = await start();
        final id = await ready(notifier, rules: taskMode, tasks: ['Read']);
        await notifier.activateProfile(id);
        screenTime.failNext = const ScreenTimeException(
          ScreenTimeError.unknown,
        );

        await notifier.toggleTask(id, taskId(id, 'Read'));
        expect(profile(id).tasks.single.isDone, isTrue);
        expect(screenTime.isShielded(id), isTrue, reason: 'the OS never heard');

        await notifier.syncWithSystem();
        expect(status(id), _open);
      },
    );

    test('an unknown task is ignored', () async {
      final notifier = await start();
      final id = await ready(notifier, tasks: ['Read']);

      await notifier.toggleTask(id, 'nope');
      await notifier.toggleTask('ghost', 'nope');

      expect(profile(id).tasks.single.isDone, isFalse);
    });

    test(
      'on a new day yesterday\'s ticks are cleared before ticking',
      () async {
        final notifier = await start();
        final id = await ready(
          notifier,
          rules: taskMode,
          tasks: ['Read', 'Run'],
        );
        await notifier.activateProfile(id);
        await notifier.toggleTask(id, taskId(id, 'Read'));
        await notifier.toggleTask(id, taskId(id, 'Run'));
        expect(status(id), _open);

        now = DateTime(2026, 11, 18, 8);
        await notifier.toggleTask(id, taskId(id, 'Read'));

        final tasks = {for (final t in profile(id).tasks) t.title: t.isDone};
        expect(tasks, {'Read': true, 'Run': false});
        expect(profile(id).tasksLastResetDate, '2026-11-18');
        expect(screenTime.isShielded(id), isTrue);
      },
    );

    test('rapid changes are applied one after another', () async {
      final notifier = await start();
      final id = await ready(notifier);

      await Future.wait([
        notifier.addTask(id, 'One'),
        notifier.addTask(id, 'Two'),
        notifier.addTask(id, 'Three'),
      ]);

      expect(profile(id).tasks.map((t) => t.title), ['One', 'Two', 'Three']);
      expect(persisted().single.tasks, hasLength(3));
    });
  });

  group('syncing with the OS', () {
    test('reports the status of every active profile', () async {
      final notifier = await start();
      final blocking = await ready(notifier);
      final armed = await ready(notifier, rules: (p) => schedule(p, 14, 16));
      await ready(notifier);
      await notifier.activateProfile(blocking);
      await notifier.activateProfile(armed);
      screenTime.calls.clear();

      await notifier.syncWithSystem();

      expect(screenTime.calls, ['sync:$blocking,$armed']);
      expect(container.read(shieldStatusProvider), {
        blocking: _shielded,
        armed: _open,
      });
    });

    test(
      'a schedule that has ended shows as open, the profile stays active',
      () async {
        final notifier = await start();
        final id = await ready(notifier, rules: (p) => schedule(p, 9, 17));
        await notifier.activateProfile(id);

        now = DateTime(2026, 11, 17, 17, 1);
        await notifier.syncWithSystem();

        expect(status(id), _open);
        expect(profile(id).isActive, isTrue);
      },
    );

    test('re-locks task mode on a new day', () async {
      final notifier = await start();
      final id = await ready(notifier, rules: taskMode, tasks: ['Read']);
      await notifier.activateProfile(id);
      await notifier.toggleTask(id, taskId(id, 'Read'));
      expect(status(id), _open);

      now = DateTime(2026, 11, 18, 7);
      await notifier.syncWithSystem();

      expect(profile(id).tasks.single.isDone, isFalse);
      expect(profile(id).tasksLastResetDate, '2026-11-18');
      expect(persisted().single.tasks.single.isDone, isFalse);
      expect(status(id), _shielded);
    });

    test('clears yesterday\'s ticks of inactive profiles too', () async {
      final notifier = await start(
        stored: const [
          BlockerProfile(
            id: 'a',
            name: 'Stamped',
            tasksLastResetDate: '2026-11-16',
            tasks: [BlockerTask(id: 't', title: 'Read', isDone: true)],
          ),
          BlockerProfile(
            id: 'b',
            name: 'Never stamped',
            tasks: [BlockerTask(id: 't', title: 'Read', isDone: true)],
          ),
        ],
      );

      await notifier.syncWithSystem();

      expect(profile('a').tasks.single.isDone, isFalse);
      expect(profile('b').tasks.single.isDone, isTrue);
      expect(profile('b').tasksLastResetDate, '2026-11-17');
    });

    test('a profile the OS no longer enforces becomes inactive', () async {
      final notifier = await start();
      final id = await ready(notifier);
      await notifier.activateProfile(id);
      screenTime.active.remove(id);
      now = now.add(const Duration(minutes: 30));

      await notifier.syncWithSystem();

      expect(profile(id).isActive, isFalse);
      expect(profile(id).totalSavedMinutes, 30);
      expect(persisted().single.isActive, isFalse);
      expect(status(id), isNull);
    });

    test('lifts blocks the app does not know about', () async {
      final notifier = await start();
      screenTime
        ..selections['orphan'] = 2
        ..active['orphan'] = const ActivationRequest(
          profileId: 'orphan',
          name: 'Left behind',
        );
      expect(screenTime.isShielded('orphan'), isTrue);

      await notifier.syncWithSystem();

      expect(screenTime.isShielded('orphan'), isFalse);
    });

    test('a failed sync leaves everything as it was', () async {
      final notifier = await start();
      final id = await ready(notifier);
      await notifier.activateProfile(id);
      screenTime.failNext = const ScreenTimeException(
        ScreenTimeError.unavailable,
      );

      await notifier.syncWithSystem();

      expect(profile(id).isActive, isTrue);
      expect(status(id), _shielded);
    });
  });

  group('uninstall protection', () {
    test('deleting apps is locked exactly while a profile is active', () async {
      final notifier = await start();
      final first = await ready(notifier);
      final second = await ready(notifier);
      expect(screenTime.removalLocked, isFalse);

      await notifier.activateProfile(first);
      await notifier.activateProfile(second);
      expect(screenTime.removalLocked, isTrue);

      await notifier.deactivateProfile(first);
      expect(screenTime.removalLocked, isTrue, reason: 'one is still active');

      await notifier.deactivateProfile(second);
      expect(screenTime.removalLocked, isFalse);
    });

    test(
      'an armed profile that is not blocking right now still locks',
      () async {
        final notifier = await start();
        final id = await ready(notifier, rules: (p) => schedule(p, 14, 16));

        await notifier.activateProfile(id);

        expect(screenTime.isShielded(id), isFalse);
        expect(screenTime.removalLocked, isTrue);
      },
    );

    test('switched off, nothing is locked', () async {
      final notifier = await start();
      final id = await ready(notifier);
      final protection = container.read(uninstallProtectionProvider.notifier);
      expect(container.read(uninstallProtectionProvider), isTrue);

      expect(await protection.set(false), isTrue);
      await notifier.activateProfile(id);

      expect(screenTime.removalLocked, isFalse);
      expect(container.read(uninstallProtectionProvider), isFalse);
      expect(prefs.getBool(PrefKeys.uninstallProtection), isFalse);
    });

    test('the setting only changes when the OS accepted it', () async {
      await start();
      final protection = container.read(uninstallProtectionProvider.notifier);
      screenTime.failNext = const ScreenTimeException(
        ScreenTimeError.unavailable,
      );

      expect(await protection.set(false), isFalse);

      expect(container.read(uninstallProtectionProvider), isTrue);
      expect(screenTime.removalLockEnabled, isTrue);
    });

    test('deleting all data switches it back on', () async {
      final notifier = await start();
      await container.read(uninstallProtectionProvider.notifier).set(false);

      await notifier.deleteAllData();

      expect(container.read(uninstallProtectionProvider), isTrue);
      expect(screenTime.removalLockEnabled, isTrue);
    });
  });

  group('deleting all data', () {
    test('lifts every block and removes profiles, PIN and settings', () async {
      final notifier = await start();
      final id = await ready(notifier);
      await notifier.activateProfile(id);
      await container.read(pinRepositoryProvider).setPin('2468');
      await prefs.setBool(PrefKeys.onboardingSeen, true);

      await notifier.deleteAllData();

      expect(screenTime.calls.sublist(screenTime.calls.length - 2), [
        'resetAll',
        'revokeAuthorization',
      ]);
      expect(
        screenTime.authStatus,
        ScreenTimeAuthStatus.notDetermined,
        reason: 'the app starts over, including the permission',
      );
      expect(screenTime.isShielded(id), isFalse);
      expect(profiles(), isEmpty);
      expect(prefs.getKeys(), isEmpty);
      expect(await container.read(pinRepositoryProvider).hasPin(), isFalse);
      expect(container.read(shieldStatusProvider), isEmpty);
      expect(container.read(shieldActivityProvider), isEmpty);
    });

    test('still clears the app when the OS side fails', () async {
      final notifier = await start();
      await ready(notifier);
      screenTime.failNext = const ScreenTimeException(
        ScreenTimeError.unavailable,
      );

      await notifier.deleteAllData();

      expect(profiles(), isEmpty);
      expect(prefs.getKeys(), isEmpty);
    });
  });
}
