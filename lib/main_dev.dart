import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unspend/bootstrap.dart';
import 'package:unspend/core/providers.dart';
import 'package:unspend/dev/demo_data.dart';
import 'package:unspend/features/app_blocker/data/datasources/fake_screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/data/datasources/method_channel_screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/data/datasources/screen_time_datasource.dart';

/// Development entrypoint: the whole app on top of an in-memory Screen Time.
///
/// Family Controls does not work in the iOS Simulator, so the real app can
/// neither ask for permission nor pick apps there. This entrypoint swaps the
/// bridge for [FakeScreenTimeDatasource], which follows the same blocking
/// rule, and shortens the cooldown so flows can be walked through quickly:
///
///     flutter run -t lib/main_dev.dart
///
/// Options, passed with `--dart-define`:
///   • `DEMO=true`            start with sample profiles, past the
///                            introduction (handy for screenshots)
///   • `AUTH=denied`          the permission prompt is answered with "no"
///   • `CHILD_ACCOUNT=no`     the phone is not a child's (child mode fails)
///   • `COOLDOWN_SECONDS=300` cooldown length (default 10)
///   • `NATIVE=true`          keep the real bridge to the OS and only
///                            shorten the cooldown. For a real iPhone and
///                            for Android, where blocking works for real.
///
/// Without `NATIVE`, nothing is blocked for real. Never ship this entrypoint.
Future<void> main() async {
  const demo = bool.fromEnvironment('DEMO');
  const auth = String.fromEnvironment('AUTH', defaultValue: 'approved');
  const childAccount = String.fromEnvironment(
    'CHILD_ACCOUNT',
    defaultValue: 'yes',
  );
  const cooldownSeconds = int.fromEnvironment(
    'COOLDOWN_SECONDS',
    defaultValue: _defaultCooldownSeconds,
  );

  const cooldown = Duration(seconds: cooldownSeconds);
  if (const bool.fromEnvironment('NATIVE')) {
    await bootstrap(
      overrides: [cooldownDurationProvider.overrideWithValue(cooldown)],
    );
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  if (demo) await seedDemoData(prefs, DateTime.now());

  final screenTime = FakeScreenTimeDatasource(
    // With demo data the app is past the permission step.
    authStatus: demo
        ? ScreenTimeAuthStatus.approved
        : ScreenTimeAuthStatus.notDetermined,
    statusAfterRequest: auth == 'denied'
        ? ScreenTimeAuthStatus.denied
        : ScreenTimeAuthStatus.approved,
    isChildAccount: childAccount != 'no',
  );
  await restoreInto(screenTime, prefs);

  await bootstrap(
    overrides: [
      screenTimeDatasourceProvider.overrideWithValue(screenTime),
      cooldownDurationProvider.overrideWithValue(cooldown),
    ],
  );
}

/// Long enough to see the countdown, short enough not to wait for it.
const _defaultCooldownSeconds = 10;
