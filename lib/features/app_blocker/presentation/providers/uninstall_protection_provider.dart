import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unspend/core/storage_keys.dart';

import '../../../../core/providers.dart';
import '../../data/datasources/method_channel_screen_time_datasource.dart';
import '../../data/datasources/screen_time_datasource.dart';

/// Whether uninstall protection is on (the default).
///
/// While it is on and a profile is active, iOS does not let anyone delete
/// apps from the phone, so removing Unspend is not a way around a block.
/// iOS only offers this for all apps at once, which is why it can be
/// switched off.
final uninstallProtectionProvider =
    NotifierProvider<UninstallProtectionNotifier, bool>(
      UninstallProtectionNotifier.new,
    );

class UninstallProtectionNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref
          .watch(sharedPreferencesProvider)
          .getBool(PrefKeys.uninstallProtection) ??
      true;

  /// Switches the protection. Returns false, changing nothing, when the OS
  /// side could not be updated.
  Future<bool> set(bool enabled) async {
    try {
      await ref
          .read(screenTimeDatasourceProvider)
          .setRemovalLockEnabled(enabled);
    } on ScreenTimeException catch (e) {
      debugPrint('[UninstallProtection] Updating the OS side failed: $e');
      return false;
    }
    state = enabled;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(PrefKeys.uninstallProtection, enabled);
    return true;
  }
}
