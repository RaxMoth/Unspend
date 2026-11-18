import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screen_time_contract.dart';
import 'screen_time_datasource.dart';

/// The Screen Time bridge in use. Overridden with a fake in tests and in
/// `main_dev.dart` (Family Controls does not work in the Simulator).
final screenTimeDatasourceProvider = Provider<ScreenTimeDatasource>(
  (ref) => const MethodChannelScreenTimeDatasource(),
);

/// Talks to `ScreenTimeChannel.swift` and `AppPickerChannel` in the Runner.
///
/// Whatever goes wrong on the way — an error from the native side, a
/// missing implementation, a reply in an unexpected shape — surfaces as a
/// [ScreenTimeException] or a safe default, never as a crash.
class MethodChannelScreenTimeDatasource implements ScreenTimeDatasource {
  const MethodChannelScreenTimeDatasource();

  static const channel = MethodChannel(ScreenTimeChannels.screenTime);
  static const pickerChannel = MethodChannel(ScreenTimeChannels.appPicker);

  /// Native error code → [ScreenTimeError].
  static const _errors = {
    ScreenTimeErrorCode.notAuthorized: ScreenTimeError.notAuthorized,
    ScreenTimeErrorCode.noSelection: ScreenTimeError.noSelection,
    ScreenTimeErrorCode.tooManyApps: ScreenTimeError.tooManyApps,
    ScreenTimeErrorCode.scheduleTooShort: ScreenTimeError.scheduleTooShort,
    ScreenTimeErrorCode.tooManyActivities: ScreenTimeError.tooManyActivities,
    ScreenTimeErrorCode.profileActive: ScreenTimeError.profileActive,
    ScreenTimeErrorCode.noAppGroup: ScreenTimeError.unavailable,
    ScreenTimeErrorCode.notChildAccount: ScreenTimeError.notChildAccount,
    ScreenTimeErrorCode.authorizationConflict:
        ScreenTimeError.authorizationConflict,
    ScreenTimeErrorCode.network: ScreenTimeError.network,
  };

  /// Calls [method] and returns the reply if it has the expected type.
  Future<T?> _invoke<T>(
    MethodChannel channel,
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    final Object? reply;
    try {
      reply = await channel.invokeMethod<Object?>(method, arguments);
    } on PlatformException catch (e) {
      throw ScreenTimeException(
        _errors[e.code] ?? ScreenTimeError.unknown,
        e.message ?? e.code,
      );
    } on MissingPluginException {
      throw const ScreenTimeException(ScreenTimeError.unavailable);
    }
    return reply is T ? reply : null;
  }

  Future<Map<Object?, Object?>?> _invokeForMap(
    String method, [
    Map<String, Object?>? arguments,
  ]) => _invoke<Map<Object?, Object?>>(channel, method, arguments);

  static ScreenTimeAuthStatus _authStatus(Object? raw) => switch (raw) {
    ScreenTimeReply.approved => ScreenTimeAuthStatus.approved,
    ScreenTimeReply.denied => ScreenTimeAuthStatus.denied,
    _ => ScreenTimeAuthStatus.notDetermined,
  };

  static ShieldStatus _status(Object? raw) {
    final map = raw is Map ? raw : const <Object?, Object?>{};
    return ShieldStatus(
      shielded: map[ScreenTimeReply.shielded] == true,
      limitReachedToday: map[ScreenTimeReply.limitReached] == true,
    );
  }

  static List<String> _strings(Object? raw) =>
      raw is List ? raw.whereType<String>().toList() : const [];

  @override
  Future<ScreenTimeAuthStatus> authorizationStatus() async => _authStatus(
    await _invoke<String>(channel, ScreenTimeMethod.authorizationStatus),
  );

  @override
  Future<ScreenTimeAuthStatus> requestAuthorization({
    required ScreenTimeMember member,
  }) async => _authStatus(
    await _invoke<String>(channel, ScreenTimeMethod.requestAuthorization, {
      ScreenTimeArg.member: member.name,
    }),
  );

  @override
  Future<void> revokeAuthorization() =>
      _invoke<bool>(channel, ScreenTimeMethod.revokeAuthorization);

  @override
  Future<void> openSettings() =>
      _invoke<bool>(channel, ScreenTimeMethod.openSettings);

  @override
  Future<int?> pickApps({
    required String profileId,
    required AppPickerLabels labels,
  }) => _invoke<int>(pickerChannel, ScreenTimeMethod.showPicker, {
    ScreenTimeArg.profileId: profileId,
    ...labels.toMap(),
  });

  @override
  Future<ShieldStatus> activate(ActivationRequest request) async =>
      _status(await _invokeForMap(ScreenTimeMethod.activate, request.toMap()));

  @override
  Future<void> deactivate(String profileId) => _invoke<bool>(
    channel,
    ScreenTimeMethod.deactivate,
    {ScreenTimeArg.profileId: profileId},
  );

  @override
  Future<ShieldStatus> setTasksDone(
    String profileId, {
    required bool done,
  }) async => _status(
    await _invokeForMap(ScreenTimeMethod.setTasksDone, {
      ScreenTimeArg.profileId: profileId,
      ScreenTimeArg.done: done,
    }),
  );

  @override
  Future<Map<String, ShieldStatus>> sync(
    List<ActiveProfileState> active,
  ) async {
    final raw = await _invokeForMap(ScreenTimeMethod.sync, {
      ScreenTimeArg.profiles: [for (final profile in active) profile.toMap()],
    });
    return {
      for (final MapEntry(:key, :value) in (raw ?? const {}).entries)
        if (key is String) key: _status(value),
    };
  }

  @override
  Future<void> deleteProfile(String profileId) => _invoke<bool>(
    channel,
    ScreenTimeMethod.deleteProfile,
    {ScreenTimeArg.profileId: profileId},
  );

  @override
  Future<void> resetAll(List<String> profileIds) => _invoke<bool>(
    channel,
    ScreenTimeMethod.resetAll,
    {ScreenTimeArg.profileIds: profileIds},
  );

  @override
  Future<void> setRemovalLockEnabled(bool enabled) => _invoke<bool>(
    channel,
    ScreenTimeMethod.setRemovalLockEnabled,
    {ScreenTimeArg.enabled: enabled},
  );

  @override
  Future<void> setShieldStrings(ShieldStrings strings) => _invoke<bool>(
    channel,
    ScreenTimeMethod.setShieldStrings,
    strings.toMap(),
  );

  @override
  Future<ScreenTimeDiagnostics> diagnostics() async {
    final raw =
        await _invokeForMap(ScreenTimeMethod.diagnostics) ??
        const <Object?, Object?>{};
    return ScreenTimeDiagnostics(
      authorization: _authStatus(raw[ScreenTimeReply.authorization]),
      removalLocked: raw[ScreenTimeReply.removalLocked] == true,
      activeProfileIds: _strings(raw[ScreenTimeReply.activeProfileIds]),
      shieldedProfileIds: _strings(raw[ScreenTimeReply.shieldedProfileIds]),
      monitoredActivities: _strings(raw[ScreenTimeReply.monitoredActivities]),
      eventLog: _strings(raw[ScreenTimeReply.eventLog]),
    );
  }

  @override
  Future<String> appVersion() async =>
      await _invoke<String>(channel, ScreenTimeMethod.appVersion) ?? '';
}
