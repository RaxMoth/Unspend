import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';

/// The current time, refreshed once a minute while the app is in the
/// foreground (by `AppLifecycleHost`).
///
/// Widgets that show whether a profile is blocking right now watch this, so
/// a schedule window opening or closing shows up without any interaction.
final currentMinuteProvider = StateProvider<DateTime>(
  (ref) => ref.read(clockProvider)(),
);
