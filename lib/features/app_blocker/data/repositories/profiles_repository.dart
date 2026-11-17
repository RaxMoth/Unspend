import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unspend/core/providers.dart';

import '../../domain/entities/blocker_profile.dart';

final profilesRepositoryProvider = Provider<ProfilesRepository>(
  (ref) => ProfilesRepository(ref.watch(sharedPreferencesProvider)),
);

/// Persists the list of [BlockerProfile]s as JSON in SharedPreferences and
/// migrates data written by older versions of the app.
class ProfilesRepository {
  ProfilesRepository(this._prefs);

  final SharedPreferences _prefs;

  static const profilesKey = 'blocker_profiles_v3';
  static const schemaVersionKey = 'blocker_schema_version';
  static const currentSchemaVersion = 3;

  /// Keys used by schema versions 1 and 2.
  static const legacyKeys = ['blocker_profiles_v2', 'blocker_profiles'];

  /// Loads all profiles. Unreadable data yields an empty list rather than a
  /// crash: a user with a corrupt store should still be able to open the app.
  Future<List<BlockerProfile>> load() async {
    try {
      await _migrateIfNeeded();
      final raw = _prefs.getString(profilesKey);
      if (raw == null) return [];
      return _decode(raw);
    } catch (e) {
      debugPrint('[ProfilesRepository] Failed to load profiles: $e');
      return [];
    }
  }

  Future<void> save(List<BlockerProfile> profiles) async {
    final encoded = json.encode(profiles.map((p) => p.toJson()).toList());
    await _prefs.setString(profilesKey, encoded);
  }

  static List<BlockerProfile> _decode(String raw) => (json.decode(raw) as List)
      .map((e) => BlockerProfile.fromJson(e as Map<String, dynamic>))
      .toList();

  /// Moves data stored under a legacy key to the current one. Re-encoding
  /// through [BlockerProfile.fromJson] fills defaults for newer fields.
  Future<void> _migrateIfNeeded() async {
    final version = _prefs.getInt(schemaVersionKey) ?? 0;
    if (version >= currentSchemaVersion) return;

    final legacy =
        _prefs.getString(profilesKey) ??
        legacyKeys.map(_prefs.getString).nonNulls.firstOrNull;
    if (legacy != null) {
      try {
        await save(_decode(legacy));
      } catch (e) {
        debugPrint('[ProfilesRepository] Migration parse failed: $e');
      }
    }
    for (final key in legacyKeys) {
      await _prefs.remove(key);
    }
    await _prefs.setInt(schemaVersionKey, currentSchemaVersion);
  }
}
