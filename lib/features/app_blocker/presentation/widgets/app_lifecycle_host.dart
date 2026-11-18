import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/strings.dart';
import '../../../../core/providers.dart';
import '../../../../core/time/day_key.dart';
import '../../../../shared/providers/locale_provider.dart';
import '../../data/datasources/method_channel_screen_time_datasource.dart';
import '../../data/datasources/screen_time_datasource.dart';
import '../native_strings.dart';
import '../providers/authorization_provider.dart';
import '../providers/current_minute_provider.dart';
import '../providers/profiles_provider.dart';

/// Keeps the app in step with the outside world while it is on screen.
///
///  • On start and every time the app returns to the foreground: re-read the
///    Screen Time permission and sync the profiles with the OS (blocks may
///    have started or ended, tasks may be due for their daily reset).
///  • Once a minute: refresh [currentMinuteProvider]; when the day changed,
///    sync again so the midnight reset shows up without leaving the app.
///  • On start and on every language change: hand the shield screen's text
///    to the OS in the app's language.
class AppLifecycleHost extends ConsumerStatefulWidget {
  const AppLifecycleHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleHost> createState() => _AppLifecycleHostState();
}

class _AppLifecycleHostState extends ConsumerState<AppLifecycleHost>
    with WidgetsBindingObserver {
  Timer? _minuteTimer;
  String? _lastSyncDay;

  DateTime _now() => ref.read(clockProvider)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Providers may not be modified while the tree is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pushShieldStrings();
      _refresh();
      _scheduleNextMinute();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _minuteTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _scheduleNextMinute();
    } else if (state == AppLifecycleState.paused) {
      _minuteTimer?.cancel();
    }
  }

  void _refresh() {
    final now = _now();
    _lastSyncDay = dayKey(now);
    ref.read(currentMinuteProvider.notifier).state = now;
    unawaited(ref.read(authorizationProvider.notifier).refresh());
    unawaited(ref.read(profilesProvider.notifier).syncWithSystem());
  }

  void _scheduleNextMinute() {
    _minuteTimer?.cancel();
    final now = _now();
    final untilNextMinute = Duration(
      seconds: 60 - now.second,
      milliseconds: -now.millisecond,
    );
    _minuteTimer = Timer(untilNextMinute, () {
      if (!mounted) return;
      final now = _now();
      if (dayKey(now) != _lastSyncDay) {
        _refresh();
      } else {
        ref.read(currentMinuteProvider.notifier).state = now;
      }
      _scheduleNextMinute();
    });
  }

  Future<void> _pushShieldStrings() async {
    try {
      await ref
          .read(screenTimeDatasourceProvider)
          .setShieldStrings(shieldStrings(S.current));
    } on ScreenTimeException catch (e) {
      debugPrint('[AppLifecycleHost] Setting the shield text failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(localeProvider, (_, _) => _pushShieldStrings());
    return widget.child;
  }
}
