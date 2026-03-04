import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/screen_time_datasource.dart';
import '../../data/datasources/mock_screen_time_datasource.dart';
import '../../domain/entities/blocker_config.dart';

/// Set to `false` once your Apple Developer license is active
/// and the FamilyControls capability is configured.
const kUseMockScreenTime = true;

const _kConfigKey = 'blocker_config';
const _kPinHashKey = 'blocker_pin_hash';
const _kPinSaltKey = 'blocker_pin_salt';

final screenTimeDatasourceProvider = Provider<ScreenTimeDatasource>(
  (_) => kUseMockScreenTime ? MockScreenTimeDatasource() : ScreenTimeDatasource(),
);

final appBlockerProvider =
    AsyncNotifierProvider<AppBlockerNotifier, BlockerConfig>(
  AppBlockerNotifier.new,
);

class AppBlockerNotifier extends AsyncNotifier<BlockerConfig> {
  late ScreenTimeDatasource _datasource;

  @override
  Future<BlockerConfig> build() async {
    _datasource = ref.read(screenTimeDatasourceProvider);

    // Restore saved config
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kConfigKey);
    if (saved != null) {
      try {
        final config = BlockerConfig.fromJson(
          json.decode(saved) as Map<String, dynamic>,
        );
        // Re-check actual shield state from OS
        final isActive = await _datasource.isShieldActive();
        return config.copyWith(isShieldActive: isActive);
      } catch (_) {
        // Bad data — fall through to defaults
      }
    }

    final isActive = await _datasource.isShieldActive();
    return BlockerConfig(isShieldActive: isActive, hasAppsSelected: false);
  }

  Future<void> _persist(BlockerConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kConfigKey, json.encode(config.toJson()));
  }

  Future<void> requestAuthorization() async {
    await _datasource.requestAuthorization();
  }

  Future<void> showAppPicker() async {
    await _datasource.showAppPicker();
    final updated = state.requireValue.copyWith(hasAppsSelected: true);
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> activateShieldNow() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _datasource.applyShield();
      final updated = state.requireValue.copyWith(isShieldActive: true);
      await _persist(updated);
      return updated;
    });
  }

  Future<void> deactivateShield() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _datasource.removeShield();
      await _datasource.stopMonitoring();
      final updated = state.requireValue.copyWith(isShieldActive: false);
      await _persist(updated);
      return updated;
    });
  }

  Future<void> setSchedule({
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
  }) async {
    state = await AsyncValue.guard(() async {
      await _datasource.startSchedule(
        startHour: startHour, startMinute: startMinute,
        endHour: endHour, endMinute: endMinute,
      );
      final updated = state.requireValue.copyWith(
        scheduleStartHour: startHour, scheduleStartMinute: startMinute,
        scheduleEndHour: endHour, scheduleEndMinute: endMinute,
      );
      await _persist(updated);
      return updated;
    });
  }

  Future<void> setUsageLimit({required int minutes}) async {
    state = await AsyncValue.guard(() async {
      await _datasource.startUsageLimit(minutes: minutes);
      final updated = state.requireValue.copyWith(usageLimitMinutes: minutes);
      await _persist(updated);
      return updated;
    });
  }

  // ── PIN management ──────────────────────────────────────────────────────

  /// Save a hashed PIN. Returns true on success.
  Future<bool> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = List.generate(16, (_) => Random.secure().nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final hash = sha256.convert(utf8.encode('$salt:$pin')).toString();
    await prefs.setString(_kPinSaltKey, salt);
    await prefs.setString(_kPinHashKey, hash);
    return true;
  }

  /// Verify a PIN against the stored hash.
  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = prefs.getString(_kPinSaltKey);
    final storedHash = prefs.getString(_kPinHashKey);
    if (salt == null || storedHash == null) return false;
    final hash = sha256.convert(utf8.encode('$salt:$pin')).toString();
    return hash == storedHash;
  }

  /// Check if a PIN has been set.
  Future<bool> hasPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kPinHashKey);
  }
}
