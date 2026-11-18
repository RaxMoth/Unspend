import 'package:unspend/bootstrap.dart';
import 'package:unspend/core/providers.dart';
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
///   • `AUTH=denied`          the permission prompt is answered with "no"
///   • `CHILD_ACCOUNT=no`     the phone is not a child's (child mode fails)
///   • `COOLDOWN_SECONDS=300` cooldown length (default 10)
///
/// Nothing is blocked for real. Never ship this entrypoint.
void main() {
  const auth = String.fromEnvironment('AUTH', defaultValue: 'approved');
  const childAccount = String.fromEnvironment(
    'CHILD_ACCOUNT',
    defaultValue: 'yes',
  );
  const cooldownSeconds = int.fromEnvironment(
    'COOLDOWN_SECONDS',
    defaultValue: 10,
  );

  bootstrap(
    overrides: [
      screenTimeDatasourceProvider.overrideWithValue(
        FakeScreenTimeDatasource(
          authStatus: ScreenTimeAuthStatus.notDetermined,
          statusAfterRequest: auth == 'denied'
              ? ScreenTimeAuthStatus.denied
              : ScreenTimeAuthStatus.approved,
          isChildAccount: childAccount != 'no',
        ),
      ),
      cooldownDurationProvider.overrideWithValue(
        const Duration(seconds: cooldownSeconds),
      ),
    ],
  );
}
