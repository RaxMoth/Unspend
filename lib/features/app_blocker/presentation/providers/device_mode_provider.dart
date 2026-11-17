import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../data/datasources/screen_time_datasource.dart';

/// Who the phone belongs to, chosen during onboarding.
enum DeviceMode {
  /// The owner blocks apps for themselves.
  personal,

  /// A parent or guardian manages a child's phone.
  child;

  /// The kind of Screen Time access this mode asks iOS for.
  ScreenTimeMember get member => switch (this) {
    DeviceMode.personal => ScreenTimeMember.individual,
    DeviceMode.child => ScreenTimeMember.child,
  };
}

/// The chosen [DeviceMode]. It decides which kind of Screen Time access is
/// requested; to change it once access is granted, go through
/// `AuthorizationNotifier.changeDeviceMode`.
final deviceModeProvider = NotifierProvider<DeviceModeNotifier, DeviceMode>(
  DeviceModeNotifier.new,
);

class DeviceModeNotifier extends Notifier<DeviceMode> {
  static const storageKey = 'device_mode';

  @override
  DeviceMode build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(storageKey);
    return DeviceMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => DeviceMode.personal,
    );
  }

  Future<void> set(DeviceMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(storageKey, mode.name);
  }
}
