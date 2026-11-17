import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screen_time_datasource.dart';

/// The Screen Time bridge in use. Overridden with a fake in tests and in
/// `main_dev.dart` (Family Controls does not work in the Simulator).
final screenTimeDatasourceProvider = Provider<ScreenTimeDatasource>(
  (ref) => const MethodChannelScreenTimeDatasource(),
);

/// Talks to `ScreenTimeChannel.swift` and `AppPickerChannel` in the Runner.
class MethodChannelScreenTimeDatasource implements ScreenTimeDatasource {
  const MethodChannelScreenTimeDatasource();

  static const channel = MethodChannel('com.maxroth.backyourtime/screentime');
  static const pickerChannel = MethodChannel(
    'com.maxroth.backyourtime/apppicker',
  );

  /// Native error code → [ScreenTimeError].
  static const _errors = {
    'NOT_AUTHORIZED': ScreenTimeError.notAuthorized,
    'NO_SELECTION': ScreenTimeError.noSelection,
    'TOO_MANY_APPS': ScreenTimeError.tooManyApps,
    'SCHEDULE_TOO_SHORT': ScreenTimeError.scheduleTooShort,
    'TOO_MANY_ACTIVITIES': ScreenTimeError.tooManyActivities,
    'PROFILE_ACTIVE': ScreenTimeError.profileActive,
    'NO_APP_GROUP': ScreenTimeError.unavailable,
    'NOT_CHILD_ACCOUNT': ScreenTimeError.notChildAccount,
    'AUTH_CONFLICT': ScreenTimeError.authorizationConflict,
    'NETWORK': ScreenTimeError.network,
  };

  Future<T?> _invoke<T>(
    MethodChannel channel,
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw ScreenTimeException(
        _errors[e.code] ?? ScreenTimeError.unknown,
        e.message ?? e.code,
      );
    } on MissingPluginException {
      throw const ScreenTimeException(ScreenTimeError.unavailable);
    }
  }

  static ScreenTimeAuthStatus _authStatus(String? raw) => switch (raw) {
    'approved' => ScreenTimeAuthStatus.approved,
    'denied' => ScreenTimeAuthStatus.denied,
    _ => ScreenTimeAuthStatus.notDetermined,
  };

  static ShieldStatus _status(Map<Object?, Object?>? raw) => ShieldStatus(
    shielded: raw?['shielded'] as bool? ?? false,
    limitReachedToday: raw?['limitReached'] as bool? ?? false,
  );

  static List<String> _strings(Object? raw) =>
      (raw as List<Object?>? ?? const []).whereType<String>().toList();

  @override
  Future<ScreenTimeAuthStatus> authorizationStatus() async =>
      _authStatus(await _invoke<String>(channel, 'authorizationStatus'));

  @override
  Future<ScreenTimeAuthStatus> requestAuthorization({
    required ScreenTimeMember member,
  }) async => _authStatus(
    await _invoke<String>(channel, 'requestAuthorization', {
      'member': member.name,
    }),
  );

  @override
  Future<void> revokeAuthorization() =>
      _invoke<bool>(channel, 'revokeAuthorization');

  @override
  Future<void> openSettings() => _invoke<bool>(channel, 'openSettings');

  @override
  Future<int?> pickApps({
    required String profileId,
    required AppPickerLabels labels,
  }) => _invoke<int>(pickerChannel, 'showPicker', {
    'profileId': profileId,
    ...labels.toMap(),
  });

  @override
  Future<ShieldStatus> activate(ActivationRequest request) async => _status(
    await _invoke<Map<Object?, Object?>>(channel, 'activate', request.toMap()),
  );

  @override
  Future<void> deactivate(String profileId) =>
      _invoke<bool>(channel, 'deactivate', {'profileId': profileId});

  @override
  Future<ShieldStatus> setTasksDone(
    String profileId, {
    required bool done,
  }) async => _status(
    await _invoke<Map<Object?, Object?>>(channel, 'setTasksDone', {
      'profileId': profileId,
      'done': done,
    }),
  );

  @override
  Future<Map<String, ShieldStatus>> sync(
    List<ActiveProfileState> active,
  ) async {
    final raw = await _invoke<Map<Object?, Object?>>(channel, 'sync', {
      'profiles': [for (final profile in active) profile.toMap()],
    });
    return {
      for (final entry in (raw ?? const {}).entries)
        if (entry.key is String)
          entry.key! as String: _status(entry.value as Map<Object?, Object?>?),
    };
  }

  @override
  Future<void> deleteProfile(String profileId) =>
      _invoke<bool>(channel, 'deleteProfile', {'profileId': profileId});

  @override
  Future<void> resetAll(List<String> profileIds) =>
      _invoke<bool>(channel, 'resetAll', {'profileIds': profileIds});

  @override
  Future<void> setRemovalLockEnabled(bool enabled) =>
      _invoke<bool>(channel, 'setRemovalLockEnabled', {'enabled': enabled});

  @override
  Future<void> setShieldStrings(ShieldStrings strings) =>
      _invoke<bool>(channel, 'setShieldStrings', strings.toMap());

  @override
  Future<ScreenTimeDiagnostics> diagnostics() async {
    final raw = await _invoke<Map<Object?, Object?>>(channel, 'diagnostics');
    return ScreenTimeDiagnostics(
      authorization: _authStatus(raw?['authorization'] as String?),
      removalLocked: raw?['removalLocked'] as bool? ?? false,
      activeProfileIds: _strings(raw?['activeProfileIds']),
      shieldedProfileIds: _strings(raw?['shieldedProfileIds']),
      monitoredActivities: _strings(raw?['monitoredActivities']),
      eventLog: _strings(raw?['eventLog']),
    );
  }
}
