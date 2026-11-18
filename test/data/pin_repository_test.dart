import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unspend/core/security/pin_hasher.dart';
import 'package:unspend/core/storage_keys.dart';
import 'package:unspend/features/app_blocker/data/repositories/pin_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late SharedPreferences prefs;
  const storage = FlutterSecureStorage();

  Future<PinRepository> build({
    Map<String, String> keychain = const {},
    Map<String, Object> preferences = const {},
  }) async {
    FlutterSecureStorage.setMockInitialValues(Map.of(keychain));
    SharedPreferences.setMockInitialValues(Map.of(preferences));
    prefs = await SharedPreferences.getInstance();
    return PinRepository(storage: storage, prefs: prefs, clock: () => now);
  }

  Future<void> failTimes(PinRepository repo, int times) async {
    for (var i = 0; i < times; i++) {
      await repo.verify('wrong');
    }
  }

  setUp(() => now = DateTime(2026, 11, 17, 12));

  group('setting and checking', () {
    test('no PIN on a fresh install', () async {
      final repo = await build();

      expect(await repo.hasPin(), isFalse);
      expect(await repo.verify('1234'), isA<PinWrong>());
    });

    test('a saved PIN verifies, a different one does not', () async {
      final repo = await build();
      await repo.setPin('2468');

      expect(await repo.hasPin(), isTrue);
      expect(await repo.verify('2468'), isA<PinCorrect>());
      expect(await repo.verify('2469'), isA<PinWrong>());
    });

    test('the PIN itself is never stored', () async {
      final repo = await build();
      await repo.setPin('2468');

      final all = await storage.readAll();
      expect(all.values, isNot(contains('2468')));
      expect(all[SecureKeys.pinHash], hasLength(64));
      expect(all[SecureKeys.pinSalt], hasLength(32));
    });

    test('setting a new PIN replaces the old one', () async {
      final repo = await build();
      await repo.setPin('1111');
      await repo.setPin('2222');

      expect(await repo.verify('1111'), isA<PinWrong>());
      expect(await repo.verify('2222'), isA<PinCorrect>());
    });

    test('clear removes the PIN', () async {
      final repo = await build();
      await repo.setPin('1111');
      await repo.clear();

      expect(await repo.hasPin(), isFalse);
      expect(await storage.readAll(), isEmpty);
    });
  });

  group('lockout', () {
    test('the fifth wrong attempt locks for 30 seconds', () async {
      final repo = await build();
      await repo.setPin('1111');

      await failTimes(repo, 4);
      expect(await repo.lockoutRemaining(), isNull);

      final fifth = await repo.verify('wrong');
      expect(fifth, isA<PinLockedOut>());
      expect((fifth as PinLockedOut).remaining, const Duration(seconds: 30));
    });

    test('even the correct PIN is refused while locked out', () async {
      final repo = await build();
      await repo.setPin('1111');
      await failTimes(repo, 5);

      now = now.add(const Duration(seconds: 10));
      final result = await repo.verify('1111');

      expect(result, isA<PinLockedOut>());
      expect((result as PinLockedOut).remaining, const Duration(seconds: 20));
    });

    test('the PIN works again once the lockout has passed', () async {
      final repo = await build();
      await repo.setPin('1111');
      await failTimes(repo, 5);

      now = now.add(const Duration(seconds: 31));

      expect(await repo.lockoutRemaining(), isNull);
      expect(await repo.verify('1111'), isA<PinCorrect>());
    });

    test(
      'lockouts get longer: the tenth wrong attempt locks for 60s',
      () async {
        final repo = await build();
        await repo.setPin('1111');
        await failTimes(repo, 5);
        now = now.add(const Duration(seconds: 31));

        await failTimes(repo, 4);
        final tenth = await repo.verify('wrong');

        expect((tenth as PinLockedOut).remaining, const Duration(seconds: 60));
      },
    );

    test('a correct PIN resets the attempt counter', () async {
      final repo = await build();
      await repo.setPin('1111');
      await failTimes(repo, 4);
      expect(await repo.verify('1111'), isA<PinCorrect>());

      await failTimes(repo, 4);

      expect(await repo.lockoutRemaining(), isNull);
    });

    test('the counter survives a new repository instance', () async {
      final repo = await build();
      await repo.setPin('1111');
      await failTimes(repo, 4);

      // Same Keychain, fresh object — as after reopening the dialog or the app.
      final reopened = PinRepository(
        storage: storage,
        prefs: prefs,
        clock: () => now,
      );

      expect(await reopened.verify('wrong'), isA<PinLockedOut>());
    });

    test('setting a new PIN clears an existing lockout', () async {
      final repo = await build();
      await repo.setPin('1111');
      await failTimes(repo, 5);

      await repo.setPin('2222');

      expect(await repo.lockoutRemaining(), isNull);
      expect(await repo.verify('2222'), isA<PinCorrect>());
    });
  });

  group('legacy migration', () {
    test('moves a PIN from SharedPreferences into the Keychain', () async {
      const salt = 'abcd';
      final repo = await build(
        preferences: {
          SecureKeys.pinSalt: salt,
          SecureKeys.pinHash: PinHasher.hash(salt, '4321'),
        },
      );

      expect(await repo.hasPin(), isTrue);
      expect(await repo.verify('4321'), isA<PinCorrect>());
      expect(prefs.getString(SecureKeys.pinHash), isNull);
      expect(prefs.getString(SecureKeys.pinSalt), isNull);
    });

    test('an existing Keychain PIN wins over a legacy one', () async {
      const legacySalt = 'old';
      const salt = 'new';
      final repo = await build(
        keychain: {
          SecureKeys.pinSalt: salt,
          SecureKeys.pinHash: PinHasher.hash(salt, '9999'),
        },
        preferences: {
          SecureKeys.pinSalt: legacySalt,
          SecureKeys.pinHash: PinHasher.hash(legacySalt, '1111'),
        },
      );

      expect(await repo.verify('9999'), isA<PinCorrect>());
      expect(await repo.verify('1111'), isA<PinWrong>());
      expect(prefs.getString(SecureKeys.pinHash), isNull);
    });
  });
}
