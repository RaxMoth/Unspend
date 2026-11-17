import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unspend/features/app_blocker/data/datasources/method_channel_screen_time_datasource.dart';
import 'package:unspend/features/app_blocker/data/datasources/screen_time_datasource.dart';

/// Pins down the contract with `ScreenTimeChannel.swift`: method names,
/// argument keys, reply shapes and error codes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const datasource = MethodChannelScreenTimeDatasource();
  const channels = [
    MethodChannelScreenTimeDatasource.channel,
    MethodChannelScreenTimeDatasource.pickerChannel,
  ];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final calls = <MethodCall>[];
  Object? Function(MethodCall call)? reply;

  setUp(() {
    calls.clear();
    reply = null;
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return reply?.call(call);
      });
    }
  });

  tearDown(() {
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  Matcher throwsScreenTime(ScreenTimeError error, {String? message}) => throwsA(
    isA<ScreenTimeException>()
        .having((e) => e.error, 'error', error)
        .having((e) => e.message, 'message', message ?? anything),
  );

  group('authorization', () {
    const answers = {
      'approved': ScreenTimeAuthStatus.approved,
      'denied': ScreenTimeAuthStatus.denied,
      'notDetermined': ScreenTimeAuthStatus.notDetermined,
      'somethingNew': ScreenTimeAuthStatus.notDetermined,
    };
    for (final MapEntry(key: raw, value: expected) in answers.entries) {
      test('"$raw" is read as ${expected.name}', () async {
        reply = (_) => raw;

        expect(await datasource.authorizationStatus(), expected);
        expect(
          await datasource.requestAuthorization(
            member: ScreenTimeMember.individual,
          ),
          expected,
        );
        expect(calls.map((c) => c.method), [
          'authorizationStatus',
          'requestAuthorization',
        ]);
      });
    }

    test('no answer counts as undecided', () async {
      expect(
        await datasource.authorizationStatus(),
        ScreenTimeAuthStatus.notDetermined,
      );
    });
  });

  group('who access is requested for', () {
    for (final member in ScreenTimeMember.values) {
      test('${member.name} is passed on', () async {
        reply = (_) => 'approved';

        await datasource.requestAuthorization(member: member);

        expect(calls.single.method, 'requestAuthorization');
        expect(calls.single.arguments, {'member': member.name});
      });
    }

    const reasons = {
      'NOT_CHILD_ACCOUNT': ScreenTimeError.notChildAccount,
      'AUTH_CONFLICT': ScreenTimeError.authorizationConflict,
      'NETWORK': ScreenTimeError.network,
    };
    for (final MapEntry(key: code, value: expected) in reasons.entries) {
      test('$code is reported as ${expected.name}', () async {
        reply = (_) => throw PlatformException(code: code);

        await expectLater(
          datasource.requestAuthorization(member: ScreenTimeMember.child),
          throwsScreenTime(expected),
        );
      });
    }

    test('access can be given back', () async {
      reply = (_) => true;

      await datasource.revokeAuthorization();

      expect(calls.single.method, 'revokeAuthorization');
    });
  });

  test('uninstall protection is switched with a flag', () async {
    reply = (_) => true;

    await datasource.setRemovalLockEnabled(false);

    expect(calls.single.method, 'setRemovalLockEnabled');
    expect(calls.single.arguments, {'enabled': false});
  });

  group('activate', () {
    test('sends every rule and reads the status', () async {
      reply = (_) => {'shielded': true, 'limitReached': false};

      final status = await datasource.activate(
        const ActivationRequest(
          profileId: 'p1',
          name: 'Evening',
          scheduleStartMinute: 1320,
          scheduleEndMinute: 360,
          usageLimitMinutes: 45,
          taskModeEnabled: true,
          tasksDone: true,
        ),
      );

      expect(calls.single.method, 'activate');
      expect(calls.single.arguments, {
        'profileId': 'p1',
        'name': 'Evening',
        'scheduleStartMinute': 1320,
        'scheduleEndMinute': 360,
        'usageLimitMinutes': 45,
        'taskModeEnabled': true,
        'tasksDone': true,
      });
      expect(
        status,
        const ShieldStatus(shielded: true, limitReachedToday: false),
      );
    });

    test('leaves out rules that are off', () async {
      reply = (_) => {'shielded': true, 'limitReached': false};

      await datasource.activate(
        const ActivationRequest(profileId: 'p1', name: 'Manual'),
      );

      expect(calls.single.arguments, {
        'profileId': 'p1',
        'name': 'Manual',
        'taskModeEnabled': false,
        'tasksDone': false,
      });
    });

    test('an empty reply reads as not blocking', () async {
      expect(
        await datasource.activate(
          const ActivationRequest(profileId: 'p1', name: 'Manual'),
        ),
        const ShieldStatus(shielded: false, limitReachedToday: false),
      );
    });
  });

  test('deactivate, deleteProfile and resetAll name their profiles', () async {
    reply = (_) => true;

    await datasource.deactivate('p1');
    await datasource.deleteProfile('p2');
    await datasource.resetAll(['p1', 'p2']);

    expect(calls.map((c) => c.method), [
      'deactivate',
      'deleteProfile',
      'resetAll',
    ]);
    expect(calls[0].arguments, {'profileId': 'p1'});
    expect(calls[1].arguments, {'profileId': 'p2'});
    expect(calls[2].arguments, {
      'profileIds': ['p1', 'p2'],
    });
  });

  test('setTasksDone sends the flag and reads the status', () async {
    reply = (_) => {'shielded': false, 'limitReached': true};

    final status = await datasource.setTasksDone('p1', done: true);

    expect(calls.single.method, 'setTasksDone');
    expect(calls.single.arguments, {'profileId': 'p1', 'done': true});
    expect(
      status,
      const ShieldStatus(shielded: false, limitReachedToday: true),
    );
  });

  group('sync', () {
    test('sends the active profiles and reads a status per profile', () async {
      reply = (_) => {
        'p1': {'shielded': true, 'limitReached': true},
        'p2': {'shielded': false, 'limitReached': false},
      };

      final statuses = await datasource.sync(const [
        ActiveProfileState(profileId: 'p1', tasksDone: false),
        ActiveProfileState(profileId: 'p2', tasksDone: true),
      ]);

      expect(calls.single.method, 'sync');
      expect(calls.single.arguments, {
        'profiles': [
          {'profileId': 'p1', 'tasksDone': false},
          {'profileId': 'p2', 'tasksDone': true},
        ],
      });
      expect(statuses, {
        'p1': const ShieldStatus(shielded: true, limitReachedToday: true),
        'p2': const ShieldStatus(shielded: false, limitReachedToday: false),
      });
    });

    test('no reply means nothing is enforced', () async {
      expect(await datasource.sync(const []), isEmpty);
    });
  });

  group('picking apps', () {
    const labels = AppPickerLabels(
      title: 'Apps wählen',
      cancel: 'Abbrechen',
      save: 'Sichern',
      tooMany: 'Zu viele',
    );

    test('sends the labels and returns the count', () async {
      reply = (_) => 4;

      expect(await datasource.pickApps(profileId: 'p1', labels: labels), 4);
      expect(calls.single.method, 'showPicker');
      expect(calls.single.arguments, {
        'profileId': 'p1',
        'title': 'Apps wählen',
        'cancel': 'Abbrechen',
        'save': 'Sichern',
        'tooMany': 'Zu viele',
      });
    });

    test('a cancelled picker returns null', () async {
      expect(
        await datasource.pickApps(profileId: 'p1', labels: labels),
        isNull,
      );
    });
  });

  test('setShieldStrings sends all six texts', () async {
    reply = (_) => true;

    await datasource.setShieldStrings(
      const ShieldStrings(
        titleTemplate: '{app} ist blockiert',
        subtitleTemplate: 'Blockiert durch „{profile}“',
        subtitleGeneric: 'Blockiert durch Unspend',
        button: 'Zurück',
        appFallback: 'Diese App',
        websiteFallback: 'Diese Website',
      ),
    );

    expect(calls.single.method, 'setShieldStrings');
    expect(calls.single.arguments, {
      'titleTemplate': '{app} ist blockiert',
      'subtitleTemplate': 'Blockiert durch „{profile}“',
      'subtitleGeneric': 'Blockiert durch Unspend',
      'button': 'Zurück',
      'appFallback': 'Diese App',
      'websiteFallback': 'Diese Website',
    });
  });

  test('diagnostics are read into typed lists', () async {
    reply = (_) => {
      'authorization': 'approved',
      'removalLocked': true,
      'activeProfileIds': ['p1', 'p2'],
      'shieldedProfileIds': ['p1'],
      'monitoredActivities': ['unspend.day.p1', 'unspend.schedule.p2'],
      'eventLog': ['11-17 12:00:00 sync 000001: shielded'],
    };

    final diagnostics = await datasource.diagnostics();

    expect(diagnostics.authorization, ScreenTimeAuthStatus.approved);
    expect(diagnostics.removalLocked, isTrue);
    expect(diagnostics.activeProfileIds, ['p1', 'p2']);
    expect(diagnostics.shieldedProfileIds, ['p1']);
    expect(diagnostics.monitoredActivities, hasLength(2));
    expect(diagnostics.eventLog.single, contains('shielded'));
  });

  group('errors', () {
    const codes = {
      'NOT_AUTHORIZED': ScreenTimeError.notAuthorized,
      'NO_SELECTION': ScreenTimeError.noSelection,
      'TOO_MANY_APPS': ScreenTimeError.tooManyApps,
      'SCHEDULE_TOO_SHORT': ScreenTimeError.scheduleTooShort,
      'TOO_MANY_ACTIVITIES': ScreenTimeError.tooManyActivities,
      'PROFILE_ACTIVE': ScreenTimeError.profileActive,
      'NO_APP_GROUP': ScreenTimeError.unavailable,
      'MONITOR_FAILED': ScreenTimeError.unknown,
      'INVALID_ARGS': ScreenTimeError.unknown,
    };
    for (final MapEntry(key: code, value: expected) in codes.entries) {
      test('$code becomes ${expected.name}', () async {
        reply = (_) => throw PlatformException(code: code, message: 'why');

        await expectLater(
          datasource.activate(
            const ActivationRequest(profileId: 'p1', name: 'x'),
          ),
          throwsScreenTime(expected, message: 'why'),
        );
      });
    }

    test('a missing native side reads as unavailable', () async {
      for (final channel in channels) {
        messenger.setMockMethodCallHandler(channel, null);
      }

      await expectLater(
        datasource.sync(const []),
        throwsScreenTime(ScreenTimeError.unavailable),
      );
      await expectLater(
        datasource.pickApps(
          profileId: 'p1',
          labels: const AppPickerLabels(
            title: 't',
            cancel: 'c',
            save: 's',
            tooMany: 'm',
          ),
        ),
        throwsScreenTime(ScreenTimeError.unavailable),
      );
    });
  });
}
