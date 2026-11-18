import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide infrastructure seams. Everything with a side effect is reached
/// through one of these so tests (and `main_dev.dart`) can swap it out.

/// The preloaded [SharedPreferences] instance. `main` overrides this after
/// awaiting `SharedPreferences.getInstance()`, which lets the rest of the app
/// read preferences synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with a loaded instance',
  ),
);

/// Keychain-backed storage for the PIN.
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  ),
);

/// Current time. Overridden with a fixed clock in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// How long the user must wait before a block can be lifted.
final cooldownDurationProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 5),
);
