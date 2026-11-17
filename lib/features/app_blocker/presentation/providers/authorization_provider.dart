import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/method_channel_screen_time_datasource.dart';
import '../../data/datasources/screen_time_datasource.dart';
import 'device_mode_provider.dart';

/// Whether the user has allowed Screen Time access. Without it nothing can
/// be blocked, so the dashboard shows a banner until it is approved.
final authorizationProvider =
    AsyncNotifierProvider<AuthorizationNotifier, ScreenTimeAuthStatus>(
      AuthorizationNotifier.new,
    );

/// Outcome of asking for Screen Time access.
class AccessRequestResult {
  const AccessRequestResult(this.status, [this.error]);

  final ScreenTimeAuthStatus status;

  /// Why access was not granted, when iOS gave a reason beyond "no".
  final ScreenTimeError? error;

  bool get approved => status == ScreenTimeAuthStatus.approved;
}

class AuthorizationNotifier extends AsyncNotifier<ScreenTimeAuthStatus> {
  ScreenTimeDatasource get _screenTime =>
      ref.read(screenTimeDatasourceProvider);

  @override
  Future<ScreenTimeAuthStatus> build() => _read();

  Future<ScreenTimeAuthStatus> _read() async {
    try {
      return await _screenTime.authorizationStatus();
    } on ScreenTimeException catch (e) {
      debugPrint('[Authorization] Reading the status failed: $e');
      return ScreenTimeAuthStatus.denied;
    }
  }

  /// Re-reads the status; the user may have changed it in Settings.
  Future<void> refresh() async {
    state = AsyncData(await _read());
  }

  /// Shows the system permission prompt — for the phone's owner or, in
  /// child mode, for a parent — and returns the answer.
  Future<AccessRequestResult> request() async {
    AccessRequestResult result;
    try {
      result = AccessRequestResult(
        await _screenTime.requestAuthorization(
          member: ref.read(deviceModeProvider).member,
        ),
      );
    } on ScreenTimeException catch (e) {
      debugPrint('[Authorization] Requesting access failed: $e');
      result = AccessRequestResult(await _read(), e.error);
    }
    state = AsyncData(result.status);
    return result;
  }

  /// Approved already, or approved after asking now.
  Future<bool> ensureApproved() async {
    final status = await _read();
    if (status == ScreenTimeAuthStatus.approved) {
      state = AsyncData(status);
      return true;
    }
    return (await request()).approved;
  }

  /// Switches between "my phone" and "my child's phone".
  ///
  /// The two need different kinds of access, so the current access is given
  /// back and requested again. Callers make sure no profile is active: iOS
  /// lifts every block when access goes away.
  ///
  /// Throws a [ScreenTimeException], changing nothing, when the current
  /// access could not be given back: iOS would keep the old kind of access
  /// and the new mode would only be a label.
  Future<AccessRequestResult> changeDeviceMode(DeviceMode mode) async {
    try {
      await _screenTime.revokeAuthorization();
    } on ScreenTimeException catch (e) {
      debugPrint('[Authorization] Giving access back failed: $e');
      if (await _read() == ScreenTimeAuthStatus.approved) rethrow;
    }
    await ref.read(deviceModeProvider.notifier).set(mode);
    return request();
  }

  Future<void> openSettings() async {
    try {
      await _screenTime.openSettings();
    } on ScreenTimeException catch (e) {
      debugPrint('[Authorization] Opening Settings failed: $e');
    }
  }
}
