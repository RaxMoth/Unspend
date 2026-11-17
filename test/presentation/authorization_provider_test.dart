import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unspend/core/providers.dart';
import 'package:unspend/features/app_blocker/data/datasources/fake_screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/data/datasources/method_channel_screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/data/datasources/screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/presentation/providers/authorization_provider.dart';
import 'package:unspend/features/app_blocker/presentation/providers/device_mode_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeScreenTimeDatasource screenTime;
  late SharedPreferences prefs;
  late ProviderContainer container;

  Future<AuthorizationNotifier> start({
    ScreenTimeAuthStatus status = ScreenTimeAuthStatus.notDetermined,
    ScreenTimeAuthStatus answer = ScreenTimeAuthStatus.approved,
    bool isChildAccount = true,
    Map<String, Object> stored = const {},
  }) async {
    SharedPreferences.setMockInitialValues(Map.of(stored));
    prefs = await SharedPreferences.getInstance();
    screenTime = FakeScreenTimeDatasource(
      authStatus: status,
      statusAfterRequest: answer,
      isChildAccount: isChildAccount,
    );
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        screenTimeDatasourceProvider.overrideWithValue(screenTime),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authorizationProvider.future);
    return container.read(authorizationProvider.notifier);
  }

  ScreenTimeAuthStatus status() =>
      container.read(authorizationProvider).requireValue;

  group('device mode', () {
    test('is "my phone" unless chosen otherwise', () async {
      await start();

      expect(container.read(deviceModeProvider), DeviceMode.personal);
      expect(DeviceMode.personal.member, ScreenTimeMember.individual);
      expect(DeviceMode.child.member, ScreenTimeMember.child);
    });

    test('is remembered', () async {
      await start();
      await container.read(deviceModeProvider.notifier).set(DeviceMode.child);
      expect(prefs.getString(DeviceModeNotifier.storageKey), 'child');

      await start(stored: {DeviceModeNotifier.storageKey: 'child'});
      expect(container.read(deviceModeProvider), DeviceMode.child);
    });

    test('an unreadable stored value falls back to "my phone"', () async {
      await start(stored: {DeviceModeNotifier.storageKey: 'teenager'});

      expect(container.read(deviceModeProvider), DeviceMode.personal);
    });
  });

  group('requesting access', () {
    test('starts from what iOS reports, without prompting', () async {
      await start(status: ScreenTimeAuthStatus.denied);

      expect(status(), ScreenTimeAuthStatus.denied);
      expect(screenTime.calls, isEmpty);
    });

    test('asks for the phone\'s owner in personal mode', () async {
      final auth = await start();

      final result = await auth.request();

      expect(result.approved, isTrue);
      expect(result.error, isNull);
      expect(screenTime.calls, ['requestAuthorization:individual']);
      expect(status(), ScreenTimeAuthStatus.approved);
    });

    test('asks for a parent\'s approval in child mode', () async {
      final auth = await start(
        stored: {DeviceModeNotifier.storageKey: 'child'},
      );

      final result = await auth.request();

      expect(result.approved, isTrue);
      expect(screenTime.calls, ['requestAuthorization:child']);
      expect(screenTime.authorizedMember, ScreenTimeMember.child);
    });

    test('a refusal is reported without a special reason', () async {
      final auth = await start(answer: ScreenTimeAuthStatus.denied);

      final result = await auth.request();

      expect(result.approved, isFalse);
      expect(result.error, isNull);
      expect(status(), ScreenTimeAuthStatus.denied);
    });

    for (final reason in [
      ScreenTimeError.notChildAccount,
      ScreenTimeError.authorizationConflict,
      ScreenTimeError.network,
    ]) {
      test('${reason.name} is passed on as the reason', () async {
        final auth = await start(
          stored: {DeviceModeNotifier.storageKey: 'child'},
        );
        screenTime.failNext = ScreenTimeException(reason);

        final result = await auth.request();

        expect(result.approved, isFalse);
        expect(result.error, reason);
        expect(status(), ScreenTimeAuthStatus.notDetermined);
      });
    }

    test('child mode on a phone that is not a child\'s is refused', () async {
      final auth = await start(
        stored: {DeviceModeNotifier.storageKey: 'child'},
        isChildAccount: false,
      );

      final result = await auth.request();

      expect(result.error, ScreenTimeError.notChildAccount);
      expect(status(), ScreenTimeAuthStatus.notDetermined);
    });

    test('ensureApproved does not prompt when access exists', () async {
      final auth = await start(status: ScreenTimeAuthStatus.approved);

      expect(await auth.ensureApproved(), isTrue);
      expect(screenTime.calls, isEmpty);
    });

    test('ensureApproved prompts once when it does not', () async {
      final auth = await start();

      expect(await auth.ensureApproved(), isTrue);
      expect(screenTime.calls, ['requestAuthorization:individual']);
    });

    test('access withdrawn in Settings is noticed on refresh', () async {
      final auth = await start(status: ScreenTimeAuthStatus.approved);
      screenTime.authStatus = ScreenTimeAuthStatus.denied;

      await auth.refresh();

      expect(status(), ScreenTimeAuthStatus.denied);
    });
  });

  group('changing who uses the phone', () {
    test('nothing changes when iOS will not give the access back', () async {
      final auth = await start();
      await auth.request();
      screenTime
        ..calls.clear()
        ..failNext = const ScreenTimeException(ScreenTimeError.unknown);

      await expectLater(
        auth.changeDeviceMode(DeviceMode.child),
        throwsA(isA<ScreenTimeException>()),
      );

      expect(screenTime.calls, ['revokeAuthorization']);
      expect(container.read(deviceModeProvider), DeviceMode.personal);
      expect(status(), ScreenTimeAuthStatus.approved);
    });

    test('gives access back and asks again for the new mode', () async {
      final auth = await start();
      await auth.request();
      screenTime.calls.clear();

      final result = await auth.changeDeviceMode(DeviceMode.child);

      expect(screenTime.calls, [
        'revokeAuthorization',
        'requestAuthorization:child',
      ]);
      expect(result.approved, isTrue);
      expect(container.read(deviceModeProvider), DeviceMode.child);
      expect(screenTime.authorizedMember, ScreenTimeMember.child);
    });

    test('a failed switch leaves the new mode without access', () async {
      final auth = await start(isChildAccount: false);
      await auth.request();

      final result = await auth.changeDeviceMode(DeviceMode.child);

      expect(result.error, ScreenTimeError.notChildAccount);
      expect(container.read(deviceModeProvider), DeviceMode.child);
      expect(status(), ScreenTimeAuthStatus.notDetermined);

      // Switching back works.
      final back = await auth.changeDeviceMode(DeviceMode.personal);
      expect(back.approved, isTrue);
      expect(container.read(deviceModeProvider), DeviceMode.personal);
    });

    test('is refused while a profile is active', () async {
      final auth = await start();
      await auth.request();
      screenTime
        ..selections['p'] = 1
        ..active['p'] = const ActivationRequest(profileId: 'p', name: 'Active');

      await expectLater(
        auth.changeDeviceMode(DeviceMode.child),
        throwsA(
          isA<ScreenTimeException>().having(
            (e) => e.error,
            'error',
            ScreenTimeError.profileActive,
          ),
        ),
      );

      expect(container.read(deviceModeProvider), DeviceMode.personal);
      expect(screenTime.authorizedMember, ScreenTimeMember.individual);
      expect(screenTime.isShielded('p'), isTrue);
    });
  });
}
