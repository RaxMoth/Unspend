import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unspend/core/providers.dart';
import 'package:unspend/core/security/pin_hasher.dart';

final pinRepositoryProvider = Provider<PinRepository>(
  (ref) => PinRepository(
    storage: ref.watch(secureStorageProvider),
    prefs: ref.watch(sharedPreferencesProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Outcome of checking a PIN.
sealed class PinCheck {
  const PinCheck();
}

/// The PIN matched.
final class PinCorrect extends PinCheck {
  const PinCorrect();
}

/// The PIN did not match; more attempts are allowed.
final class PinWrong extends PinCheck {
  const PinWrong();
}

/// Too many wrong attempts; nothing is checked until [remaining] has passed.
final class PinLockedOut extends PinCheck {
  const PinLockedOut(this.remaining);
  final Duration remaining;
}

/// Stores the unlock PIN (salted SHA-256) in the Keychain and enforces a
/// lockout after repeated wrong attempts.
///
/// The attempt counter is persisted next to the PIN, so closing the dialog or
/// restarting the app does not hand out a fresh set of guesses.
class PinRepository {
  PinRepository({
    required FlutterSecureStorage storage,
    required SharedPreferences prefs,
    required DateTime Function() clock,
  }) : _storage = storage,
       _prefs = prefs,
       _clock = clock;

  final FlutterSecureStorage _storage;
  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  static const hashKey = 'blocker_pin_hash';
  static const saltKey = 'blocker_pin_salt';
  static const failedAttemptsKey = 'blocker_pin_failed_attempts';
  static const lockoutUntilKey = 'blocker_pin_lockout_until';

  static const minPinLength = 4;

  /// Every [attemptsPerLockout]th wrong attempt in a row locks the PIN for
  /// [lockoutStep] × (number of lockouts so far).
  static const attemptsPerLockout = 5;
  static const lockoutStep = Duration(seconds: 30);

  Future<bool> hasPin() async {
    await _migrateLegacyPin();
    return await _storage.read(key: hashKey) != null;
  }

  /// Replaces the PIN and clears any lockout. Callers must have verified the
  /// current PIN first (see `showPinGate`).
  Future<void> setPin(String pin) async {
    final salt = PinHasher.generateSalt();
    await _storage.write(key: saltKey, value: salt);
    await _storage.write(key: hashKey, value: PinHasher.hash(salt, pin));
    await _resetAttempts();
  }

  /// Time left on the current lockout, or null when the PIN can be tried.
  Future<Duration?> lockoutRemaining() async {
    final raw = await _storage.read(key: lockoutUntilKey);
    final until = raw == null ? null : DateTime.tryParse(raw);
    if (until == null) return null;
    final remaining = until.difference(_clock());
    return remaining > Duration.zero ? remaining : null;
  }

  Future<PinCheck> verify(String pin) async {
    await _migrateLegacyPin();

    final locked = await lockoutRemaining();
    if (locked != null) return PinLockedOut(locked);

    final salt = await _storage.read(key: saltKey);
    final storedHash = await _storage.read(key: hashKey);
    if (salt != null &&
        storedHash != null &&
        PinHasher.hash(salt, pin) == storedHash) {
      await _resetAttempts();
      return const PinCorrect();
    }

    final failed = await _failedAttempts() + 1;
    await _storage.write(key: failedAttemptsKey, value: '$failed');
    if (failed % attemptsPerLockout != 0) return const PinWrong();

    final lockout = lockoutStep * (failed ~/ attemptsPerLockout);
    await _storage.write(
      key: lockoutUntilKey,
      value: _clock().add(lockout).toIso8601String(),
    );
    return PinLockedOut(lockout);
  }

  /// Removes the PIN and the attempt counter.
  Future<void> clear() async {
    for (final key in [hashKey, saltKey, failedAttemptsKey, lockoutUntilKey]) {
      await _storage.delete(key: key);
    }
  }

  Future<int> _failedAttempts() async =>
      int.tryParse(await _storage.read(key: failedAttemptsKey) ?? '') ?? 0;

  Future<void> _resetAttempts() async {
    await _storage.delete(key: failedAttemptsKey);
    await _storage.delete(key: lockoutUntilKey);
  }

  /// Early builds kept the PIN hash in SharedPreferences. Move it to the
  /// Keychain once and delete the insecure copy.
  Future<void> _migrateLegacyPin() async {
    final legacySalt = _prefs.getString(saltKey);
    final legacyHash = _prefs.getString(hashKey);
    if (legacySalt == null || legacyHash == null) return;

    if (await _storage.read(key: hashKey) == null) {
      await _storage.write(key: saltKey, value: legacySalt);
      await _storage.write(key: hashKey, value: legacyHash);
    }
    await _prefs.remove(saltKey);
    await _prefs.remove(hashKey);
  }
}
