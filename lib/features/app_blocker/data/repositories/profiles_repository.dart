import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unspend/core/providers.dart';
import 'package:unspend/core/storage_keys.dart';

import '../../domain/entities/blocker_profile.dart';

final profilesRepositoryProvider = Provider<ProfilesRepository>(
  (ref) => ProfilesRepository(ref.watch(sharedPreferencesProvider)),
);

/// Persists the list of [BlockerProfile]s as JSON in SharedPreferences and
/// migrates data written by older versions of the app.
class ProfilesRepository {
  ProfilesRepository(this._prefs);

  final SharedPreferences _prefs;

  /// Version of the stored format; see [_migrateIfNeeded].
  static const currentSchemaVersion = 3;

  /// Loads all profiles. Unreadable data yields an empty list rather than a
  /// crash: a user with a corrupt store should still be able to open the app.
  Future<List<BlockerProfile>> load() async {
    try {
      await _migrateIfNeeded();
      final raw = _prefs.getString(PrefKeys.profiles);
      if (raw == null) return [];
      return _decode(raw);
    } catch (e) {
      debugPrint('[ProfilesRepository] Failed to load profiles: $e');
      return [];
    }
  }

  Future<void> save(List<BlockerProfile> profiles) async {
    final encoded = json.encode(profiles.map((p) => p.toJson()).toList());
    await _prefs.setString(PrefKeys.profiles, encoded);
  }

  static List<BlockerProfile> _decode(String raw) => (json.decode(raw) as List)
      .map((e) => BlockerProfile.fromJson(e as Map<String, dynamic>))
      .toList();

  /// Moves data stored under a legacy key to the current one. Re-encoding
  /// through [BlockerProfile.fromJson] fills defaults for newer fields.
  Future<void> _migrateIfNeeded() async {
    final version = _prefs.getInt(PrefKeys.profilesSchemaVersion) ?? 0;
    if (version >= currentSchemaVersion) return;

    final legacy =
        _prefs.getString(PrefKeys.profiles) ??
        PrefKeys.legacyProfiles.map(_prefs.getString).nonNulls.firstOrNull;
    if (legacy != null) {
      try {
        await save(_decode(legacy));
      } catch (e) {
        debugPrint('[ProfilesRepository] Migration parse failed: $e');
      }
    }
    for (final key in PrefKeys.legacyProfiles) {
      await _prefs.remove(key);
    }
    await _prefs.setInt(PrefKeys.profilesSchemaVersion, currentSchemaVersion);
  }
}
