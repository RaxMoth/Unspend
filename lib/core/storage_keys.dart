/// Every key the app stores something under, in one place: a reader can see
/// everything that is persisted, and two features cannot pick the same key.
///
/// Renaming a value here loses what users have stored under it. Add a
/// migration instead (see `ProfilesRepository`).
library;

/// Keys in SharedPreferences (plain, on-device settings and data).
abstract final class PrefKeys {
  /// Whether the introduction has been completed.
  static const onboardingSeen = 'has_seen_onboarding';

  /// Chosen app language ('en', 'de', …); absent means "follow the device".
  static const locale = 'app_locale';

  /// Chosen theme ('system', 'light', 'dark').
  static const themeMode = 'app_theme_mode';

  /// Who uses the phone ('personal', 'child').
  static const deviceMode = 'device_mode';

  /// Whether deleting apps is locked while a profile is active.
  static const uninstallProtection = 'uninstall_protection';

  /// The profiles, as a JSON list, and the version of that format.
  static const profiles = 'blocker_profiles_v3';
  static const profilesSchemaVersion = 'blocker_schema_version';

  /// Where earlier versions kept the profiles; read once, then removed.
  static const legacyProfiles = ['blocker_profiles_v2', 'blocker_profiles'];

  /// Day → peak number of active profiles (for a future statistics screen).
  static const shieldDailyLog = 'shield_daily_log';
}

/// Keys in the Keychain (the unlock PIN and its attempt counter).
abstract final class SecureKeys {
  static const pinHash = 'blocker_pin_hash';
  static const pinSalt = 'blocker_pin_salt';
  static const pinFailedAttempts = 'blocker_pin_failed_attempts';
  static const pinLockoutUntil = 'blocker_pin_lockout_until';
}
