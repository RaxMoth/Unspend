import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/time/day_key.dart';

/// Day (`yyyy-MM-dd`) → the highest number of profiles that were active at
/// the same time on that day.
///
/// Recorded for a future statistics screen; nothing displays it yet.
final shieldActivityProvider =
    NotifierProvider<ShieldActivityNotifier, Map<String, int>>(
      ShieldActivityNotifier.new,
    );

class ShieldActivityNotifier extends Notifier<Map<String, int>> {
  static const storageKey = 'shield_daily_log';

  /// Older entries are dropped to keep storage bounded.
  static const retention = Duration(days: 180);

  @override
  Map<String, int> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(storageKey);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((day, count) => MapEntry(day, (count as num).toInt()));
    } catch (_) {
      return const {};
    }
  }

  /// Records today's number of active profiles, keeping the day's peak.
  Future<void> record(int activeCount) async {
    final now = ref.read(clockProvider)();
    final today = dayKey(now);
    final previous = state[today];
    if (previous != null && previous >= activeCount) return;

    final cutoff = now.subtract(retention);
    final log = {
      for (final entry in state.entries)
        if (DateTime.tryParse(entry.key)?.isAfter(cutoff) ?? false)
          entry.key: entry.value,
      today: activeCount,
    };
    state = log;
    await ref
        .read(sharedPreferencesProvider)
        .setString(storageKey, jsonEncode(log));
  }
}
