import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unspend/core/storage_keys.dart';
import 'package:unspend/features/app_blocker/data/repositories/profiles_repository.dart';
import 'package:unspend/features/app_blocker/domain/entities/blocker_profile.dart';

Future<(ProfilesRepository, SharedPreferences)> _repo(
  Map<String, Object> initial,
) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  return (ProfilesRepository(prefs), prefs);
}

String _encode(List<BlockerProfile> profiles) =>
    json.encode(profiles.map((p) => p.toJson()).toList());

void main() {
  const work = BlockerProfile(
    id: 'p1',
    name: 'Work',
    hasAppsSelected: true,
    appCount: 3,
    scheduleEnabled: true,
    scheduleStartHour: 9,
    scheduleStartMinute: 0,
    scheduleEndHour: 17,
    scheduleEndMinute: 30,
  );
  const evening = BlockerProfile(
    id: 'p2',
    name: 'Evening',
    taskModeEnabled: true,
    tasks: [BlockerTask(id: 't1', title: 'Read', isDone: true)],
  );

  test('load returns an empty list on a fresh install', () async {
    final (repo, prefs) = await _repo({});

    expect(await repo.load(), isEmpty);
    expect(
      prefs.getInt(PrefKeys.profilesSchemaVersion),
      ProfilesRepository.currentSchemaVersion,
    );
  });

  test('save then load round-trips every profile', () async {
    final (repo, _) = await _repo({});

    await repo.save([work, evening]);
    final loaded = await repo.load();

    expect(loaded.map((p) => p.id), ['p1', 'p2']);
    expect(loaded[0].scheduleEndMinute, 30);
    expect(loaded[1].tasks.single.isDone, isTrue);
  });

  test('migrates data stored under the v2 key', () async {
    final (repo, prefs) = await _repo({
      'blocker_profiles_v2': _encode([work]),
    });

    final loaded = await repo.load();

    expect(loaded.single.name, 'Work');
    expect(prefs.getString('blocker_profiles_v2'), isNull);
    expect(prefs.getString(PrefKeys.profiles), isNotNull);
  });

  test('migrates data stored under the v1 key', () async {
    final (repo, prefs) = await _repo({
      'blocker_profiles': _encode([evening]),
    });

    final loaded = await repo.load();

    expect(loaded.single.name, 'Evening');
    expect(prefs.getString('blocker_profiles'), isNull);
  });

  test('prefers v2 over v1 when both legacy keys exist', () async {
    final (repo, _) = await _repo({
      'blocker_profiles_v2': _encode([work]),
      'blocker_profiles': _encode([evening]),
    });

    expect((await repo.load()).single.id, 'p1');
  });

  test(
    'does not re-run migration once the schema version is current',
    () async {
      final (repo, prefs) = await _repo({
        PrefKeys.profilesSchemaVersion: ProfilesRepository.currentSchemaVersion,
        PrefKeys.profiles: _encode([work]),
        'blocker_profiles_v2': _encode([evening]),
      });

      expect((await repo.load()).single.id, 'p1');
      // Legacy key is left alone because no migration ran.
      expect(prefs.getString('blocker_profiles_v2'), isNotNull);
    },
  );

  test('corrupt JSON yields an empty list instead of throwing', () async {
    final (repo, _) = await _repo({
      PrefKeys.profilesSchemaVersion: ProfilesRepository.currentSchemaVersion,
      PrefKeys.profiles: '{not json',
    });

    expect(await repo.load(), isEmpty);
  });

  test('a corrupt legacy value is dropped during migration', () async {
    final (repo, prefs) = await _repo({'blocker_profiles_v2': '[{"id": 7}]'});

    expect(await repo.load(), isEmpty);
    expect(prefs.getString('blocker_profiles_v2'), isNull);
  });

  test('missing fields in stored JSON fall back to defaults', () async {
    final (repo, _) = await _repo({
      PrefKeys.profilesSchemaVersion: ProfilesRepository.currentSchemaVersion,
      PrefKeys.profiles: '[{"id": "x"}]',
    });

    final profile = (await repo.load()).single;
    expect(profile.id, 'x');
    expect(profile.isActive, isFalse);
    expect(profile.tasks, isEmpty);
  });
}
