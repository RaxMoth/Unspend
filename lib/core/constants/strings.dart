import 'dart:io' show Platform;

import 'package:shared_preferences/shared_preferences.dart';

/// Centralised user-facing strings with locale support.
/// Supported: English (en), Deutsch (de), Español (es), Français (fr), Hrvatski (hr).
///
/// Call [S.init] once at app start (before `runApp`).
/// Access via the top-level [S] instance, e.g. `S.current.appName`.
abstract class S {
  S._();

  static const _kLocaleKey = 'app_locale';

  /// All supported language codes.
  static const supportedLocales = ['en', 'de', 'es', 'fr', 'hr'];

  // ── Singleton access ─────────────────────────────────────────────────────
  static late S current;

  static S _forCode(String code) => switch (code) {
    'de' => _De(),
    'es' => _Es(),
    'fr' => _Fr(),
    'hr' => _Hr(),
    _ => _En(),
  };

  /// Must be called once before `runApp`.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kLocaleKey);
      if (saved != null) {
        current = _forCode(saved);
      } else {
        final lang = Platform.localeName.split('_').first.toLowerCase();
        current = _forCode(lang);
      }
    } catch (_) {
      current = _En();
    }
  }

  /// Change locale at runtime and persist the choice.
  static Future<void> setLocale(String langCode) async {
    current = _forCode(langCode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocaleKey, langCode);
    } catch (_) {
      // best-effort persist
    }
  }

  /// The active language code.
  static String get langCode {
    if (current is _De) return 'de';
    if (current is _Es) return 'es';
    if (current is _Fr) return 'fr';
    if (current is _Hr) return 'hr';
    return 'en';
  }

  // ── General ──────────────────────────────────────────────────────────────
  String get appName;
  String get cancel;
  String get save;
  String get delete;
  String get create;
  String get untitled;

  // ── Dashboard ────────────────────────────────────────────────────────────
  String get profilesSectionTitle;
  String get noProfilesYet;
  String get noProfilesTapPlus;
  String get noAppsWarning;
  String get noTasksWarning;

  // ── Summary Card ─────────────────────────────────────────────────────────
  String get allShieldsActive;
  String someShieldsActive(int active, int total);
  String get noProfiles;
  String get shieldsInactive;
  String get blockingDistractingApps;
  String get createProfileToStart;
  String get noProfilesAreActive;

  // ── Create Profile Sheet ─────────────────────────────────────────────────
  String get newProfile;
  String get createProfileDescription;
  String get profileNameHint;

  // ── Settings ─────────────────────────────────────────────────────────────
  String get settings;
  String get changePin;
  String get changePinSubtitle;
  String get languageLabel;
  String get themeLabel;
  String get themeSystem;
  String get themeLight;
  String get themeDark;

  // ── Profile Detail ───────────────────────────────────────────────────────
  String get profileNamePlaceholder;
  String get sectionColor;
  String get sectionIcon;
  String get sectionApps;
  String get sectionBlockRules;
  String get blockRulesDescription;
  String appsSelected(int count);
  String get selectAppsToBlock;
  String get tapToChooseApps;
  String get tapToEditSelection;

  // ── Time picker ──────────────────────────────────────────────────────────
  String get pickerModeWheel;
  String get pickerModeKeypad;
  String get hoursShort;
  String get minutesShort;

  // ── Block Rules ──────────────────────────────────────────────────────────
  String get scheduleTitle;
  String get scheduleDescription;
  String get scheduleStart;
  String get scheduleEnd;

  String get usageLimitTitle;
  String get usageLimitDescription;
  String get dailyLimit;

  String get taskModeTitle;
  String get taskModeDescription;

  // ── Activate / Deactivate ────────────────────────────────────────────────
  String get activateShield;
  String get deactivateShield;
  String get selectAppsToActivate;
  String get settingsLockedWhileActive;

  // ── Requirement reasons (used by entity) ─────────────────────────────────
  String get reasonManualMode;
  String get reasonInsideSchedule;
  String reasonTasksRemaining(int remaining);
  String get reasonAllMet;

  // ── Subtitle helpers (used by entity) ────────────────────────────────────
  String get noAppsSelected;
  String subtitleApps(int count);
  String subtitleUsageLimit(int minutes);
  String subtitleTasks(int done, int total);
  String get subtitleManual;

  /// Format "HH:mm" for schedule times in subtitle. German uses " Uhr" suffix.
  String subtitleScheduleRange(String start, String end);

  // ── Delete Profile Dialog ────────────────────────────────────────────────
  String get deleteProfile;
  String deleteProfileConfirm(String name);

  // ── Task List ────────────────────────────────────────────────────────────
  String get tasks;
  String get addTaskHint;
  String get allTasksDoneNote;
  String tasksRemainingNote(int remaining);
  String get emptyTasksHint;

  // ── PIN Setup Dialog ─────────────────────────────────────────────────────
  String get setPinTitle;
  String get setPinDescription;
  String get enterPin;
  String get confirmPin;
  String get savePin;
  String get pinTooShort;
  String get pinsMismatch;

  // ── Timer + PIN Deactivation Dialog ──────────────────────────────────────
  String get enterPinToDeactivate;
  String get confirmDeactivation;
  String get deactivateAction;
  String get areYouSureDeactivate;
  String get cooldownDescription;
  String get enterTrustedPersonPin;
  String get pinLabel;
  String get enterYourPin;
  String get incorrectPin;
  String pinLockedOut(int seconds);

  // ── Privacy Policy ──────────────────────────────────────────────────────
  String get privacyPolicyTitle;
  String get privacyPolicySubtitle;
  String get privacyPolicyBody;

  // ── Delete All Data ─────────────────────────────────────────────────────
  String get deleteAllData;
  String get deleteAllDataSubtitle;
  String get deleteAllDataConfirm;
  String get deleteAllDataWarning;

  // ── Onboarding ──────────────────────────────────────────────────────────
  String get onboardingTitle1;
  String get onboardingBody1;
  String get onboardingTitle2;
  String get onboardingBody2;
  String get onboardingTitle3;
  String get onboardingBody3;
  String get getStarted;
  String get next;
  String get skip;

  // ── Common actions ──────────────────────────────────────────────────────
  String get notNow;
  String get continueLabel;
  String get openSettings;
  String get pageNotFound;
  String get errorTryAgain;

  // ── Screen Time authorization ───────────────────────────────────────────
  String get authBannerTitle;
  String get authBannerBody;
  String get authAllow;
  String get authDeniedHint;
  String get authGranted;
  String get onboardingTitle4;
  String get onboardingBody4;

  // ── Blocking errors and states ──────────────────────────────────────────
  String get reasonLimitReached;
  String get errorNotAuthorized;
  String get errorScheduleTooShort;
  String get errorTooManyActivities;
  String get deactivationFailed;
  String get cooldownGeneric;

  // ── App picker (shown by iOS, labels supplied by us) ────────────────────
  String get pickerTitle;
  String get pickerTooManyApps;

  // ── Shield screen shown over a blocked app. `{app}` and `{profile}` are
  //    replaced natively. ──────────────────────────────────────────────────
  String get shieldTitleTemplate;
  String get shieldSubtitleTemplate;
  String get shieldSubtitleGeneric;
  String get shieldButton;
  String get shieldAppFallback;
  String get shieldWebsiteFallback;

  // ── Accessibility ───────────────────────────────────────────────────────
  String get showPin;
  String get hidePin;
  String get statusActive;
  String get statusInactive;
  String get addTask;
  String deleteTaskLabel(String title);

  // ── Misc ────────────────────────────────────────────────────────────────
  String get errorUnavailable;
  String get goHome;
  String get pinSaved;
  // ── Who uses the phone, uninstall protection ────────────────────────────
  String get whoUsesTitle;
  String get whoUsesBody;
  String get modePersonalTitle;
  String get modePersonalBody;
  String get modeChildTitle;
  String get modeChildBody;
  String get modePersonalShort;
  String get modeChildShort;
  String get onboardingBody4Child;
  String get authNotChildAccount;
  String get authConflict;
  String get authNetwork;
  String get whoUsesLabel;
  String get whoUsesChangeInfo;
  String get deactivateAllFirst;
  String get uninstallProtection;
  String get uninstallProtectionBody;
  String get stateOn;
  String get stateOff;
  String tasksProgress(int done, int total);

  /// Display name for a [ProfileColor.name] identifier.
  String colorName(String id);

  /// Display name for a [ProfileIcon.label] identifier.
  String iconName(String id);
}

// ═══════════════════════════════════════════════════════════════════════════
// ── English (default) ──────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════
class _En extends S {
  _En() : super._();

  @override
  String get appName => 'Unspend';
  @override
  String get cancel => 'Cancel';
  @override
  String get save => 'Save';
  @override
  String get delete => 'Delete';
  @override
  String get create => 'Create';
  @override
  String get untitled => 'Untitled';

  @override
  String get profilesSectionTitle => 'Profiles';
  @override
  String get noProfilesYet => 'No profiles yet';
  @override
  String get noProfilesTapPlus =>
      'Tap + to create your first blocking profile.';
  @override
  String get noAppsWarning => 'No apps in this group — select apps first';
  @override
  String get noTasksWarning =>
      'Add at least one task before activating task mode';

  @override
  String get allShieldsActive => 'All Shields Active';
  @override
  String someShieldsActive(int active, int total) => '$active of $total Active';
  @override
  String get noProfiles => 'No Profiles';
  @override
  String get shieldsInactive => 'Shields Inactive';
  @override
  String get blockingDistractingApps => 'Blocking distracting apps';
  @override
  String get createProfileToStart => 'Create a profile to get started';
  @override
  String get noProfilesAreActive => 'No profiles are active';

  @override
  String get newProfile => 'New Profile';
  @override
  String get createProfileDescription =>
      'Create a group of apps with its own blocking rules.';
  @override
  String get profileNameHint => 'e.g. Social Media, Games…';

  @override
  String get settings => 'Settings';
  @override
  String get changePin => 'Change PIN';
  @override
  String get changePinSubtitle => 'Trusted-person deactivation PIN';
  @override
  String get languageLabel => 'Language';
  @override
  String get themeLabel => 'Theme';
  @override
  String get themeSystem => 'System';
  @override
  String get themeLight => 'Light';
  @override
  String get themeDark => 'Dark';

  @override
  String get profileNamePlaceholder => 'Profile Name';
  @override
  String get sectionColor => 'Color';
  @override
  String get sectionIcon => 'Icon';
  @override
  String get sectionApps => 'Apps';
  @override
  String get sectionBlockRules => 'Block Rules';
  @override
  String get blockRulesDescription =>
      'Combine any rules below. With none enabled, use Activate Shield for manual control.';
  @override
  String appsSelected(int count) => '$count apps selected';
  @override
  String get selectAppsToBlock => 'Select Apps to Block';
  @override
  String get tapToChooseApps => 'Tap to choose the apps this profile blocks';
  @override
  String get tapToEditSelection => 'Tap to view or change the selection';
  @override
  String get pickerModeWheel => 'Wheel';
  @override
  String get pickerModeKeypad => 'Keypad';
  @override
  String get hoursShort => 'HRS';
  @override
  String get minutesShort => 'MIN';

  @override
  String get scheduleTitle => 'Schedule';
  @override
  String get scheduleDescription => 'Hard-block during a daily time window';
  @override
  String get scheduleStart => 'Start';
  @override
  String get scheduleEnd => 'End';

  @override
  String get usageLimitTitle => 'Usage Limit';
  @override
  String get usageLimitDescription =>
      'Soft-block after a daily screen-time budget';
  @override
  String get dailyLimit => 'Daily Limit';

  @override
  String get taskModeTitle => 'Task Mode';
  @override
  String get taskModeDescription => 'Block until all tasks are completed';

  @override
  String get activateShield => 'Activate Shield';
  @override
  String get deactivateShield => 'Deactivate Shield';
  @override
  String get selectAppsToActivate => 'Select Apps to Activate';
  @override
  String get settingsLockedWhileActive =>
      'Settings are locked while the shield is active. Deactivate to make changes.';

  @override
  String get reasonManualMode => 'Manual mode — deactivate to unlock';
  @override
  String get reasonInsideSchedule => 'Inside schedule window';
  @override
  String reasonTasksRemaining(int r) => '$r task${r == 1 ? '' : 's'} remaining';
  @override
  String get reasonAllMet => 'All requirements met — apps accessible';

  @override
  String get noAppsSelected => 'No apps selected';
  @override
  String subtitleApps(int count) => '$count apps';
  @override
  String subtitleUsageLimit(int minutes) => '${minutes}min limit';
  @override
  String subtitleTasks(int done, int total) => '$done/$total tasks';
  @override
  String get subtitleManual => 'Manual';
  @override
  String subtitleScheduleRange(String start, String end) => '$start–$end';

  @override
  String get deleteProfile => 'Delete Profile';
  @override
  String deleteProfileConfirm(String name) =>
      'Delete "$name"? This cannot be undone.';

  @override
  String get tasks => 'Tasks';
  @override
  String get addTaskHint => 'Add a task…';
  @override
  String get allTasksDoneNote => 'All tasks done!';
  @override
  String tasksRemainingNote(int r) =>
      '$r task${r == 1 ? '' : 's'} remaining to unlock';
  @override
  String get emptyTasksHint =>
      'Add tasks that must be completed before apps unlock.';

  @override
  String get setPinTitle => 'Set Deactivation PIN';
  @override
  String get setPinDescription =>
      'Hand your phone to a trusted person.\nThey set a PIN that is required to deactivate any shield.';
  @override
  String get enterPin => 'Enter PIN';
  @override
  String get confirmPin => 'Confirm PIN';
  @override
  String get savePin => 'Save PIN';
  @override
  String get pinTooShort => 'PIN must be at least 4 characters';
  @override
  String get pinsMismatch => 'PINs do not match';

  @override
  String get enterPinToDeactivate => 'Enter PIN to Deactivate';
  @override
  String get confirmDeactivation => 'Confirm Deactivation';
  @override
  String get deactivateAction => 'Deactivate';
  @override
  String get areYouSureDeactivate => 'Are you sure you want to deactivate?';
  @override
  String get cooldownDescription =>
      'Take a moment to reconsider.\nThe shield will be deactivatable after the timer.';
  @override
  String get enterTrustedPersonPin =>
      'Enter the PIN set by your trusted person.';
  @override
  String get pinLabel => 'PIN';
  @override
  String get enterYourPin => 'Enter your PIN';
  @override
  String get incorrectPin => 'Incorrect PIN';
  @override
  String pinLockedOut(int seconds) =>
      'Too many attempts. Try again in ${seconds}s';

  @override
  String get privacyPolicyTitle => 'Privacy Policy';
  @override
  String get privacyPolicySubtitle => 'How your data is handled';
  @override
  String get privacyPolicyBody =>
      'Unspend stores all data locally on your device. No personal data is collected, transmitted, or shared with third parties.\n\n'
      'Your blocking profiles, settings, and PIN are saved using on-device storage (SharedPreferences and iOS Keychain). '
      'No analytics, tracking, or telemetry is used.\n\n'
      'The app uses Apple\'s FamilyControls framework to manage app blocking. This data stays on your device and is managed entirely by iOS.\n\n'
      'You can delete all your data at any time from Settings > Delete All Data.';

  @override
  String get deleteAllData => 'Delete All Data';
  @override
  String get deleteAllDataSubtitle => 'Remove all profiles, PIN, and settings';
  @override
  String get deleteAllDataConfirm => 'Delete Everything';
  @override
  String get deleteAllDataWarning =>
      'This will permanently delete all profiles, your PIN, and all settings. Active shields will be removed. This cannot be undone.';

  @override
  String get onboardingTitle1 => 'Take Back Your Time';
  @override
  String get onboardingBody1 =>
      'Unspend helps you block distracting apps at the OS level so you can focus on what matters.';
  @override
  String get onboardingTitle2 => 'Create Blocking Profiles';
  @override
  String get onboardingBody2 =>
      'Set up profiles with combinable rules: time schedules, daily usage limits, and task-based unlocking.';
  @override
  String get onboardingTitle3 => 'Unskippable Protection';
  @override
  String get onboardingBody3 =>
      'Shields are enforced by iOS itself. A PIN and cooldown timer prevent impulsive disabling.';
  @override
  String get getStarted => 'Get Started';
  @override
  String get next => 'Next';
  @override
  String get skip => 'Skip';

  // ── v1 hardening ────────────────────────────────────────────────────────
  @override
  String get notNow => 'Not now';
  @override
  String get continueLabel => 'Continue';
  @override
  String get openSettings => 'Open Settings';
  @override
  String get pageNotFound => 'Page not found';
  @override
  String get errorTryAgain => 'Something went wrong. Please try again.';
  @override
  String get authBannerTitle => 'Screen Time access needed';
  @override
  String get authBannerBody =>
      'Unspend can\'t block apps until you allow Screen Time access.';
  @override
  String get authAllow => 'Allow access';
  @override
  String get authDeniedHint =>
      'If no prompt appears, allow access in Settings › Screen Time.';
  @override
  String get authGranted => 'Access granted';
  @override
  String get onboardingTitle4 => 'Allow Screen Time Access';
  @override
  String get onboardingBody4 =>
      'Unspend uses Apple\'s Screen Time to block the apps you choose. Your selection never leaves this device.';
  @override
  String get reasonLimitReached => 'Daily limit reached';
  @override
  String get errorNotAuthorized =>
      'Screen Time access has not been allowed yet.';
  @override
  String get errorScheduleTooShort =>
      'The schedule must be at least 15 minutes long.';
  @override
  String get errorTooManyActivities =>
      'Too many profiles are active at once. Deactivate one and try again.';
  @override
  String get deactivationFailed =>
      'Could not remove the block. Please try again.';
  @override
  String get cooldownGeneric =>
      'Take a moment to reconsider.\nYou can continue when the timer ends.';
  @override
  String get pickerTitle => 'Choose Apps';
  @override
  String get pickerTooManyApps =>
      'You can pick up to 50 individual apps. Choose whole categories to block more.';
  @override
  String get shieldTitleTemplate => '{app} is blocked';
  @override
  String get shieldSubtitleTemplate => 'Blocked by “{profile}” in Unspend';
  @override
  String get shieldSubtitleGeneric => 'Blocked by Unspend';
  @override
  String get shieldButton => 'Go Back';
  @override
  String get shieldAppFallback => 'This app';
  @override
  String get shieldWebsiteFallback => 'This website';
  @override
  String get showPin => 'Show PIN';
  @override
  String get hidePin => 'Hide PIN';
  @override
  String get statusActive => 'Active';
  @override
  String get statusInactive => 'Inactive';
  @override
  String get addTask => 'Add task';
  @override
  String deleteTaskLabel(String title) => 'Delete task “$title”';
  @override
  String get errorUnavailable => 'Screen Time is not available on this device.';
  @override
  String get goHome => 'Back to start';
  @override
  String get pinSaved => 'PIN saved';
  @override
  String get whoUsesTitle => 'Who uses this iPhone?';
  @override
  String get whoUsesBody =>
      'Unspend can hold you to your own limits, or help you look after your child\'s iPhone.';
  @override
  String get modePersonalTitle => 'This is my iPhone';
  @override
  String get modePersonalBody => 'I want to block apps for myself.';
  @override
  String get modeChildTitle => 'This is my child\'s iPhone';
  @override
  String get modeChildBody =>
      'I\'m a parent or guardian and decide what gets blocked.';
  @override
  String get modePersonalShort => 'Me';
  @override
  String get modeChildShort => 'My child';
  @override
  String get onboardingBody4Child =>
      'A parent or guardian approves Unspend with their Apple Account. After that, your child can\'t delete Unspend or switch it off.';
  @override
  String get authNotChildAccount =>
      'This iPhone isn\'t set up as a child\'s device. Add your child to Family Sharing in Settings, or choose “This is my iPhone”.';
  @override
  String get authConflict =>
      'Another app already manages Screen Time on this iPhone. Remove its access in Settings › Screen Time first.';
  @override
  String get authNetwork =>
      'Approving needs an internet connection. Please try again.';
  @override
  String get whoUsesLabel => 'Who uses this iPhone';
  @override
  String get whoUsesChangeInfo =>
      'Changing this switches Unspend\'s Screen Time access off and asks for it again.';
  @override
  String get deactivateAllFirst => 'Deactivate all profiles first.';
  @override
  String get uninstallProtection => 'Uninstall protection';
  @override
  String get uninstallProtectionBody =>
      'While a profile is active, apps can\'t be deleted from this iPhone, so removing Unspend is no way around a block. iOS can only lock deleting for all apps at once.';
  @override
  String get stateOn => 'On';
  @override
  String get stateOff => 'Off';
  @override
  String tasksProgress(int done, int total) => '$done of $total tasks done';
  @override
  String colorName(String id) => switch (id) {
    'Red' => 'Red',
    'Orange' => 'Orange',
    'Amber' => 'Amber',
    'Green' => 'Green',
    'Teal' => 'Teal',
    'Blue' => 'Blue',
    'Indigo' => 'Indigo',
    'Purple' => 'Purple',
    'Pink' => 'Pink',
    _ => id,
  };
  @override
  String iconName(String id) => switch (id) {
    'Social' => 'Social',
    'Games' => 'Games',
    'Video' => 'Video',
    'News' => 'News',
    'Shopping' => 'Shopping',
    'Chat' => 'Chat',
    'Music' => 'Music',
    'Photos' => 'Photos',
    'Work' => 'Work',
    'Custom' => 'Custom',
    _ => id,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Deutsch ────────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════
class _De extends S {
  _De() : super._();

  @override
  String get appName => 'Unspend';
  @override
  String get cancel => 'Abbrechen';
  @override
  String get save => 'Speichern';
  @override
  String get delete => 'Löschen';
  @override
  String get create => 'Erstellen';
  @override
  String get untitled => 'Unbenannt';

  @override
  String get profilesSectionTitle => 'Profile';
  @override
  String get noProfilesYet => 'Noch keine Profile';
  @override
  String get noProfilesTapPlus =>
      'Tippe auf +, um dein erstes Blockier-Profil zu erstellen.';
  @override
  String get noAppsWarning =>
      'Keine Apps in dieser Gruppe — wähle zuerst Apps aus';
  @override
  String get noTasksWarning =>
      'Füge mindestens eine Aufgabe hinzu, bevor du den Aufgabenmodus aktivierst';

  @override
  String get allShieldsActive => 'Alle Schilde aktiv';
  @override
  String someShieldsActive(int active, int total) => '$active von $total aktiv';
  @override
  String get noProfiles => 'Keine Profile';
  @override
  String get shieldsInactive => 'Schilde inaktiv';
  @override
  String get blockingDistractingApps => 'Ablenkende Apps werden blockiert';
  @override
  String get createProfileToStart => 'Erstelle ein Profil, um loszulegen';
  @override
  String get noProfilesAreActive => 'Keine Profile sind aktiv';

  @override
  String get newProfile => 'Neues Profil';
  @override
  String get createProfileDescription =>
      'Erstelle eine Gruppe von Apps mit eigenen Blockier-Regeln.';
  @override
  String get profileNameHint => 'z.\u202FB. Social Media, Spiele…';

  @override
  String get settings => 'Einstellungen';
  @override
  String get changePin => 'PIN ändern';
  @override
  String get changePinSubtitle => 'Vertrauensperson-Deaktivierungs-PIN';
  @override
  String get languageLabel => 'Sprache';
  @override
  String get themeLabel => 'Design';
  @override
  String get themeSystem => 'System';
  @override
  String get themeLight => 'Hell';
  @override
  String get themeDark => 'Dunkel';

  @override
  String get profileNamePlaceholder => 'Profilname';
  @override
  String get sectionColor => 'Farbe';
  @override
  String get sectionIcon => 'Symbol';
  @override
  String get sectionApps => 'Apps';
  @override
  String get sectionBlockRules => 'Blockier-Regeln';
  @override
  String get blockRulesDescription =>
      'Kombiniere beliebige Regeln. Ohne aktive Regeln nutze „Schild aktivieren" für manuelle Kontrolle.';
  @override
  String appsSelected(int count) => '$count Apps ausgewählt';
  @override
  String get selectAppsToBlock => 'Apps zum Blockieren auswählen';
  @override
  String get tapToChooseApps => 'Tippe, um Apps für dieses Profil zu wählen';
  @override
  String get tapToEditSelection =>
      'Tippe, um die Auswahl anzusehen oder zu ändern';
  @override
  String get pickerModeWheel => 'Rad';
  @override
  String get pickerModeKeypad => 'Zahlen';
  @override
  String get hoursShort => 'STD';
  @override
  String get minutesShort => 'MIN';

  @override
  String get scheduleTitle => 'Zeitplan';
  @override
  String get scheduleDescription =>
      'Hart-Blockierung in einem täglichen Zeitfenster';
  @override
  String get scheduleStart => 'Beginn';
  @override
  String get scheduleEnd => 'Ende';

  @override
  String get usageLimitTitle => 'Nutzungslimit';
  @override
  String get usageLimitDescription =>
      'Weich-Blockierung nach täglichem Bildschirmzeit-Budget';
  @override
  String get dailyLimit => 'Tägliches Limit';

  @override
  String get taskModeTitle => 'Aufgabenmodus';
  @override
  String get taskModeDescription =>
      'Blockieren, bis alle Aufgaben erledigt sind';

  @override
  String get activateShield => 'Schild aktivieren';
  @override
  String get deactivateShield => 'Schild deaktivieren';
  @override
  String get selectAppsToActivate => 'Apps zum Aktivieren auswählen';
  @override
  String get settingsLockedWhileActive =>
      'Einstellungen sind gesperrt, solange der Schild aktiv ist. Deaktiviere ihn, um Änderungen vorzunehmen.';

  @override
  String get reasonManualMode => 'Manueller Modus — deaktiviere zum Entsperren';
  @override
  String get reasonInsideSchedule => 'Innerhalb des Zeitfensters';
  @override
  String reasonTasksRemaining(int r) => '$r Aufgabe${r == 1 ? '' : 'n'} übrig';
  @override
  String get reasonAllMet => 'Alle Anforderungen erfüllt — Apps zugänglich';

  @override
  String get noAppsSelected => 'Keine Apps ausgewählt';
  @override
  String subtitleApps(int count) => '$count Apps';
  @override
  String subtitleUsageLimit(int minutes) => '$minutes Min Limit';
  @override
  String subtitleTasks(int done, int total) => '$done/$total Aufgaben';
  @override
  String get subtitleManual => 'Manuell';
  @override
  String subtitleScheduleRange(String start, String end) => '$start–$end Uhr';

  @override
  String get deleteProfile => 'Profil löschen';
  @override
  String deleteProfileConfirm(String name) =>
      '„$name" löschen? Das kann nicht rückgängig gemacht werden.';

  @override
  String get tasks => 'Aufgaben';
  @override
  String get addTaskHint => 'Aufgabe hinzufügen…';
  @override
  String get allTasksDoneNote => 'Alle Aufgaben erledigt!';
  @override
  String tasksRemainingNote(int r) =>
      'Noch $r Aufgabe${r == 1 ? '' : 'n'} zum Entsperren';
  @override
  String get emptyTasksHint =>
      'Füge Aufgaben hinzu, die erledigt werden müssen, bevor Apps entsperrt werden.';

  @override
  String get setPinTitle => 'Deaktivierungs-PIN festlegen';
  @override
  String get setPinDescription =>
      'Gib dein Handy einer Vertrauensperson.\nSie legt eine PIN fest, die zum Deaktivieren benötigt wird.';
  @override
  String get enterPin => 'PIN eingeben';
  @override
  String get confirmPin => 'PIN bestätigen';
  @override
  String get savePin => 'PIN speichern';
  @override
  String get pinTooShort => 'PIN muss mindestens 4 Zeichen lang sein';
  @override
  String get pinsMismatch => 'PINs stimmen nicht überein';

  @override
  String get enterPinToDeactivate => 'PIN zum Deaktivieren eingeben';
  @override
  String get confirmDeactivation => 'Deaktivierung bestätigen';
  @override
  String get deactivateAction => 'Deaktivieren';
  @override
  String get areYouSureDeactivate =>
      'Bist du sicher, dass du deaktivieren möchtest?';
  @override
  String get cooldownDescription =>
      'Nimm dir einen Moment zum Nachdenken.\nDer Schild kann nach dem Timer deaktiviert werden.';
  @override
  String get enterTrustedPersonPin =>
      'Gib die PIN deiner Vertrauensperson ein.';
  @override
  String get pinLabel => 'PIN';
  @override
  String get enterYourPin => 'PIN eingeben';
  @override
  String get incorrectPin => 'Falsche PIN';
  @override
  String pinLockedOut(int seconds) =>
      'Zu viele Versuche. Erneut in ${seconds}s';

  @override
  String get privacyPolicyTitle => 'Datenschutz';
  @override
  String get privacyPolicySubtitle => 'Wie deine Daten behandelt werden';
  @override
  String get privacyPolicyBody =>
      'Unspend speichert alle Daten lokal auf deinem Gerät. Es werden keine personenbezogenen Daten erhoben, übermittelt oder an Dritte weitergegeben.\n\n'
      'Deine Blockierprofile, Einstellungen und deine PIN werden im Gerätespeicher (SharedPreferences und iOS-Schlüsselbund) gesichert. '
      'Es werden keine Analyse-, Tracking- oder Telemetriedienste verwendet.\n\n'
      'Die App nutzt Apples FamilyControls-Framework zur App-Blockierung. Diese Daten verbleiben auf deinem Gerät und werden vollständig von iOS verwaltet.\n\n'
      'Du kannst alle Daten jederzeit unter Einstellungen > Alle Daten löschen entfernen.';

  @override
  String get deleteAllData => 'Alle Daten löschen';
  @override
  String get deleteAllDataSubtitle =>
      'Alle Profile, PIN und Einstellungen entfernen';
  @override
  String get deleteAllDataConfirm => 'Alles löschen';
  @override
  String get deleteAllDataWarning =>
      'Alle Profile, deine PIN und sämtliche Einstellungen werden unwiderruflich gelöscht. Aktive Schilde werden entfernt.';

  @override
  String get onboardingTitle1 => 'Hol dir deine Zeit zurück';
  @override
  String get onboardingBody1 =>
      'Unspend hilft dir, ablenkende Apps auf Systemebene zu blockieren, damit du dich auf das Wesentliche konzentrieren kannst.';
  @override
  String get onboardingTitle2 => 'Erstelle Blockierprofile';
  @override
  String get onboardingBody2 =>
      'Richte Profile mit kombinierbaren Regeln ein: Zeitpläne, tägliche Nutzungslimits und aufgabenbasiertes Entsperren.';
  @override
  String get onboardingTitle3 => 'Unumgehbarer Schutz';
  @override
  String get onboardingBody3 =>
      'Schilde werden von iOS selbst durchgesetzt. Eine PIN und ein Abkühl-Timer verhindern impulsives Deaktivieren.';
  @override
  String get getStarted => 'Los geht\'s';
  @override
  String get next => 'Weiter';
  @override
  String get skip => 'Überspringen';

  // ── v1 hardening ────────────────────────────────────────────────────────
  @override
  String get notNow => 'Nicht jetzt';
  @override
  String get continueLabel => 'Weiter';
  @override
  String get openSettings => 'Einstellungen öffnen';
  @override
  String get pageNotFound => 'Seite nicht gefunden';
  @override
  String get errorTryAgain =>
      'Etwas ist schiefgelaufen. Bitte versuche es erneut.';
  @override
  String get authBannerTitle => 'Zugriff auf Bildschirmzeit erforderlich';
  @override
  String get authBannerBody =>
      'Unspend kann Apps erst blockieren, wenn du den Zugriff auf Bildschirmzeit erlaubst.';
  @override
  String get authAllow => 'Zugriff erlauben';
  @override
  String get authDeniedHint =>
      'Falls keine Abfrage erscheint, erlaube den Zugriff unter Einstellungen › Bildschirmzeit.';
  @override
  String get authGranted => 'Zugriff erlaubt';
  @override
  String get onboardingTitle4 => 'Bildschirmzeit erlauben';
  @override
  String get onboardingBody4 =>
      'Unspend nutzt Apples Bildschirmzeit, um die von dir gewählten Apps zu blockieren. Deine Auswahl verlässt dieses Gerät nie.';
  @override
  String get reasonLimitReached => 'Tageslimit erreicht';
  @override
  String get errorNotAuthorized =>
      'Der Zugriff auf Bildschirmzeit wurde noch nicht erlaubt.';
  @override
  String get errorScheduleTooShort =>
      'Der Zeitplan muss mindestens 15 Minuten lang sein.';
  @override
  String get errorTooManyActivities =>
      'Zu viele Profile sind gleichzeitig aktiv. Deaktiviere eines und versuche es erneut.';
  @override
  String get deactivationFailed =>
      'Die Sperre konnte nicht aufgehoben werden. Bitte versuche es erneut.';
  @override
  String get cooldownGeneric =>
      'Nimm dir einen Moment zum Nachdenken.\nNach Ablauf des Timers kannst du fortfahren.';
  @override
  String get pickerTitle => 'Apps auswählen';
  @override
  String get pickerTooManyApps =>
      'Du kannst bis zu 50 einzelne Apps auswählen. Wähle ganze Kategorien, um mehr zu blockieren.';
  @override
  String get shieldTitleTemplate => '{app} ist blockiert';
  @override
  String get shieldSubtitleTemplate => 'Blockiert durch „{profile}“ in Unspend';
  @override
  String get shieldSubtitleGeneric => 'Blockiert durch Unspend';
  @override
  String get shieldButton => 'Zurück';
  @override
  String get shieldAppFallback => 'Diese App';
  @override
  String get shieldWebsiteFallback => 'Diese Website';
  @override
  String get showPin => 'PIN anzeigen';
  @override
  String get hidePin => 'PIN verbergen';
  @override
  String get statusActive => 'Aktiv';
  @override
  String get statusInactive => 'Inaktiv';
  @override
  String get addTask => 'Aufgabe hinzufügen';
  @override
  String deleteTaskLabel(String title) => 'Aufgabe „$title“ löschen';
  @override
  String get errorUnavailable =>
      'Bildschirmzeit ist auf diesem Gerät nicht verfügbar.';
  @override
  String get goHome => 'Zur Startseite';
  @override
  String get pinSaved => 'PIN gespeichert';
  @override
  String get whoUsesTitle => 'Wer nutzt dieses iPhone?';
  @override
  String get whoUsesBody =>
      'Unspend hilft dir, deine eigenen Grenzen einzuhalten – oder das iPhone deines Kindes zu betreuen.';
  @override
  String get modePersonalTitle => 'Das ist mein iPhone';
  @override
  String get modePersonalBody => 'Ich möchte Apps für mich selbst blockieren.';
  @override
  String get modeChildTitle => 'Das ist das iPhone meines Kindes';
  @override
  String get modeChildBody =>
      'Ich bin Elternteil oder erziehungsberechtigt und lege fest, was blockiert wird.';
  @override
  String get modePersonalShort => 'Ich';
  @override
  String get modeChildShort => 'Mein Kind';
  @override
  String get onboardingBody4Child =>
      'Ein Elternteil oder eine erziehungsberechtigte Person gibt Unspend mit dem eigenen Apple Account frei. Danach kann dein Kind Unspend weder löschen noch abschalten.';
  @override
  String get authNotChildAccount =>
      'Dieses iPhone ist nicht als Gerät eines Kindes eingerichtet. Füge dein Kind in den Einstellungen zur Familienfreigabe hinzu oder wähle „Das ist mein iPhone“.';
  @override
  String get authConflict =>
      'Eine andere App verwaltet die Bildschirmzeit auf diesem iPhone bereits. Entferne zuerst deren Zugriff unter Einstellungen › Bildschirmzeit.';
  @override
  String get authNetwork =>
      'Für die Freigabe wird eine Internetverbindung benötigt. Bitte versuche es erneut.';
  @override
  String get whoUsesLabel => 'Wer nutzt dieses iPhone';
  @override
  String get whoUsesChangeInfo =>
      'Bei einer Änderung wird der Bildschirmzeit-Zugriff von Unspend abgeschaltet und neu angefragt.';
  @override
  String get deactivateAllFirst => 'Deaktiviere zuerst alle Profile.';
  @override
  String get uninstallProtection => 'Löschschutz';
  @override
  String get uninstallProtectionBody =>
      'Solange ein Profil aktiv ist, können auf diesem iPhone keine Apps gelöscht werden – Unspend zu entfernen ist also kein Ausweg. iOS kann das Löschen nur für alle Apps gleichzeitig sperren.';
  @override
  String get stateOn => 'Ein';
  @override
  String get stateOff => 'Aus';
  @override
  String tasksProgress(int done, int total) =>
      '$done von $total Aufgaben erledigt';
  @override
  String colorName(String id) => switch (id) {
    'Red' => 'Rot',
    'Orange' => 'Orange',
    'Amber' => 'Bernstein',
    'Green' => 'Grün',
    'Teal' => 'Türkis',
    'Blue' => 'Blau',
    'Indigo' => 'Indigo',
    'Purple' => 'Violett',
    'Pink' => 'Pink',
    _ => id,
  };
  @override
  String iconName(String id) => switch (id) {
    'Social' => 'Soziales',
    'Games' => 'Spiele',
    'Video' => 'Video',
    'News' => 'Nachrichten',
    'Shopping' => 'Einkaufen',
    'Chat' => 'Chat',
    'Music' => 'Musik',
    'Photos' => 'Fotos',
    'Work' => 'Arbeit',
    'Custom' => 'Eigenes',
    _ => id,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Español ────────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════
class _Es extends S {
  _Es() : super._();

  @override
  String get appName => 'Unspend';
  @override
  String get cancel => 'Cancelar';
  @override
  String get save => 'Guardar';
  @override
  String get delete => 'Eliminar';
  @override
  String get create => 'Crear';
  @override
  String get untitled => 'Sin título';

  @override
  String get profilesSectionTitle => 'Perfiles';
  @override
  String get noProfilesYet => 'Sin perfiles aún';
  @override
  String get noProfilesTapPlus =>
      'Toca + para crear tu primer perfil de bloqueo.';
  @override
  String get noAppsWarning =>
      'No hay apps en este grupo — selecciona apps primero';
  @override
  String get noTasksWarning =>
      'Añade al menos una tarea antes de activar el modo de tareas';

  @override
  String get allShieldsActive => 'Todos los escudos activos';
  @override
  String someShieldsActive(int active, int total) =>
      '$active de $total activos';
  @override
  String get noProfiles => 'Sin perfiles';
  @override
  String get shieldsInactive => 'Escudos inactivos';
  @override
  String get blockingDistractingApps => 'Bloqueando apps de distracción';
  @override
  String get createProfileToStart => 'Crea un perfil para empezar';
  @override
  String get noProfilesAreActive => 'Ningún perfil está activo';

  @override
  String get newProfile => 'Nuevo perfil';
  @override
  String get createProfileDescription =>
      'Crea un grupo de apps con sus propias reglas de bloqueo.';
  @override
  String get profileNameHint => 'ej. Redes sociales, Juegos…';

  @override
  String get settings => 'Ajustes';
  @override
  String get changePin => 'Cambiar PIN';
  @override
  String get changePinSubtitle =>
      'PIN de desactivación de persona de confianza';
  @override
  String get languageLabel => 'Idioma';
  @override
  String get themeLabel => 'Tema';
  @override
  String get themeSystem => 'Sistema';
  @override
  String get themeLight => 'Claro';
  @override
  String get themeDark => 'Oscuro';

  @override
  String get profileNamePlaceholder => 'Nombre del perfil';
  @override
  String get sectionColor => 'Color';
  @override
  String get sectionIcon => 'Icono';
  @override
  String get sectionApps => 'Apps';
  @override
  String get sectionBlockRules => 'Reglas de bloqueo';
  @override
  String get blockRulesDescription =>
      'Combina reglas. Sin reglas activas, usa Activar escudo para control manual.';
  @override
  String appsSelected(int count) => '$count apps seleccionadas';
  @override
  String get selectAppsToBlock => 'Seleccionar apps a bloquear';
  @override
  String get tapToChooseApps =>
      'Toca para elegir las apps que este perfil bloquea';
  @override
  String get tapToEditSelection => 'Toca para ver o cambiar la selección';
  @override
  String get pickerModeWheel => 'Rueda';
  @override
  String get pickerModeKeypad => 'Teclado';
  @override
  String get hoursShort => 'HRS';
  @override
  String get minutesShort => 'MIN';

  @override
  String get scheduleTitle => 'Horario';
  @override
  String get scheduleDescription =>
      'Bloqueo fijo durante una franja horaria diaria';
  @override
  String get scheduleStart => 'Inicio';
  @override
  String get scheduleEnd => 'Fin';

  @override
  String get usageLimitTitle => 'Límite de uso';
  @override
  String get usageLimitDescription =>
      'Bloqueo suave tras un presupuesto diario de pantalla';
  @override
  String get dailyLimit => 'Límite diario';

  @override
  String get taskModeTitle => 'Modo tareas';
  @override
  String get taskModeDescription => 'Bloquear hasta completar todas las tareas';

  @override
  String get activateShield => 'Activar escudo';
  @override
  String get deactivateShield => 'Desactivar escudo';
  @override
  String get selectAppsToActivate => 'Seleccionar apps para activar';
  @override
  String get settingsLockedWhileActive =>
      'Los ajustes están bloqueados mientras el escudo está activo. Desactívalo para hacer cambios.';

  @override
  String get reasonManualMode => 'Modo manual — desactiva para desbloquear';
  @override
  String get reasonInsideSchedule => 'Dentro de la franja horaria';
  @override
  String reasonTasksRemaining(int r) =>
      '$r tarea${r == 1 ? '' : 's'} pendiente${r == 1 ? '' : 's'}';
  @override
  String get reasonAllMet => 'Todos los requisitos cumplidos — apps accesibles';

  @override
  String get noAppsSelected => 'Sin apps seleccionadas';
  @override
  String subtitleApps(int count) => '$count apps';
  @override
  String subtitleUsageLimit(int minutes) => '${minutes}min límite';
  @override
  String subtitleTasks(int done, int total) => '$done/$total tareas';
  @override
  String get subtitleManual => 'Manual';
  @override
  String subtitleScheduleRange(String start, String end) => '$start–$end';

  @override
  String get deleteProfile => 'Eliminar perfil';
  @override
  String deleteProfileConfirm(String name) =>
      '¿Eliminar "$name"? Esto no se puede deshacer.';

  @override
  String get tasks => 'Tareas';
  @override
  String get addTaskHint => 'Añadir una tarea…';
  @override
  String get allTasksDoneNote => '¡Todas las tareas completadas!';
  @override
  String tasksRemainingNote(int r) =>
      '$r tarea${r == 1 ? '' : 's'} pendiente${r == 1 ? '' : 's'} para desbloquear';
  @override
  String get emptyTasksHint =>
      'Añade tareas que deban completarse antes de desbloquear las apps.';

  @override
  String get setPinTitle => 'Establecer PIN de desactivación';
  @override
  String get setPinDescription =>
      'Dale tu teléfono a una persona de confianza.\nElla establece un PIN necesario para desactivar cualquier escudo.';
  @override
  String get enterPin => 'Introducir PIN';
  @override
  String get confirmPin => 'Confirmar PIN';
  @override
  String get savePin => 'Guardar PIN';
  @override
  String get pinTooShort => 'El PIN debe tener al menos 4 caracteres';
  @override
  String get pinsMismatch => 'Los PINs no coinciden';

  @override
  String get enterPinToDeactivate => 'Introducir PIN para desactivar';
  @override
  String get confirmDeactivation => 'Confirmar desactivación';
  @override
  String get deactivateAction => 'Desactivar';
  @override
  String get areYouSureDeactivate => '¿Estás seguro de que quieres desactivar?';
  @override
  String get cooldownDescription =>
      'Tómate un momento para reconsiderar.\nEl escudo se podrá desactivar después del temporizador.';
  @override
  String get enterTrustedPersonPin =>
      'Introduce el PIN establecido por tu persona de confianza.';
  @override
  String get pinLabel => 'PIN';
  @override
  String get enterYourPin => 'Introduce tu PIN';
  @override
  String get incorrectPin => 'PIN incorrecto';
  @override
  String pinLockedOut(int seconds) =>
      'Demasiados intentos. Inténtalo en ${seconds}s';

  @override
  String get privacyPolicyTitle => 'Política de privacidad';
  @override
  String get privacyPolicySubtitle => 'Cómo se manejan tus datos';
  @override
  String get privacyPolicyBody =>
      'Unspend almacena todos los datos localmente en tu dispositivo. No se recopilan, transmiten ni comparten datos personales con terceros.\n\n'
      'Tus perfiles de bloqueo, ajustes y PIN se guardan en el almacenamiento del dispositivo (SharedPreferences y el llavero de iOS). '
      'No se utiliza ningún servicio de análisis, rastreo o telemetría.\n\n'
      'La app usa el framework FamilyControls de Apple para gestionar el bloqueo de apps. Estos datos permanecen en tu dispositivo y son gestionados por iOS.\n\n'
      'Puedes eliminar todos tus datos en cualquier momento desde Ajustes > Eliminar todos los datos.';

  @override
  String get deleteAllData => 'Eliminar todos los datos';
  @override
  String get deleteAllDataSubtitle =>
      'Eliminar todos los perfiles, PIN y ajustes';
  @override
  String get deleteAllDataConfirm => 'Eliminar todo';
  @override
  String get deleteAllDataWarning =>
      'Se eliminarán permanentemente todos los perfiles, tu PIN y todos los ajustes. Los escudos activos serán eliminados. Esta acción no se puede deshacer.';

  @override
  String get onboardingTitle1 => 'Recupera tu tiempo';
  @override
  String get onboardingBody1 =>
      'Unspend te ayuda a bloquear apps distractoras a nivel del sistema para que puedas concentrarte en lo importante.';
  @override
  String get onboardingTitle2 => 'Crea perfiles de bloqueo';
  @override
  String get onboardingBody2 =>
      'Configura perfiles con reglas combinables: horarios, límites de uso diario y desbloqueo basado en tareas.';
  @override
  String get onboardingTitle3 => 'Protección inquebrantable';
  @override
  String get onboardingBody3 =>
      'Los escudos son aplicados por iOS mismo. Un PIN y un temporizador de espera previenen la desactivación impulsiva.';
  @override
  String get getStarted => 'Comenzar';
  @override
  String get next => 'Siguiente';
  @override
  String get skip => 'Omitir';

  // ── v1 hardening ────────────────────────────────────────────────────────
  @override
  String get notNow => 'Ahora no';
  @override
  String get continueLabel => 'Continuar';
  @override
  String get openSettings => 'Abrir Ajustes';
  @override
  String get pageNotFound => 'Página no encontrada';
  @override
  String get errorTryAgain => 'Algo salió mal. Inténtalo de nuevo.';
  @override
  String get authBannerTitle => 'Se necesita acceso a Tiempo de uso';
  @override
  String get authBannerBody =>
      'Unspend no puede bloquear apps hasta que permitas el acceso a Tiempo de uso.';
  @override
  String get authAllow => 'Permitir acceso';
  @override
  String get authDeniedHint =>
      'Si no aparece ningún aviso, permite el acceso en Ajustes › Tiempo de uso.';
  @override
  String get authGranted => 'Acceso permitido';
  @override
  String get onboardingTitle4 => 'Permite Tiempo de uso';
  @override
  String get onboardingBody4 =>
      'Unspend usa Tiempo de uso de Apple para bloquear las apps que elijas. Tu selección nunca sale de este dispositivo.';
  @override
  String get reasonLimitReached => 'Límite diario alcanzado';
  @override
  String get errorNotAuthorized =>
      'Aún no se ha permitido el acceso a Tiempo de uso.';
  @override
  String get errorScheduleTooShort =>
      'El horario debe durar al menos 15 minutos.';
  @override
  String get errorTooManyActivities =>
      'Hay demasiados perfiles activos a la vez. Desactiva uno e inténtalo de nuevo.';
  @override
  String get deactivationFailed =>
      'No se pudo quitar el bloqueo. Inténtalo de nuevo.';
  @override
  String get cooldownGeneric =>
      'Tómate un momento para pensarlo.\nPodrás continuar cuando termine el temporizador.';
  @override
  String get pickerTitle => 'Elegir apps';
  @override
  String get pickerTooManyApps =>
      'Puedes elegir hasta 50 apps individuales. Elige categorías completas para bloquear más.';
  @override
  String get shieldTitleTemplate => 'Bloqueado: {app}';
  @override
  String get shieldSubtitleTemplate => 'Bloqueado por «{profile}» en Unspend';
  @override
  String get shieldSubtitleGeneric => 'Bloqueado por Unspend';
  @override
  String get shieldButton => 'Volver';
  @override
  String get shieldAppFallback => 'Esta app';
  @override
  String get shieldWebsiteFallback => 'Este sitio web';
  @override
  String get showPin => 'Mostrar PIN';
  @override
  String get hidePin => 'Ocultar PIN';
  @override
  String get statusActive => 'Activo';
  @override
  String get statusInactive => 'Inactivo';
  @override
  String get addTask => 'Añadir tarea';
  @override
  String deleteTaskLabel(String title) => 'Eliminar la tarea «$title»';
  @override
  String get errorUnavailable =>
      'Tiempo de uso no está disponible en este dispositivo.';
  @override
  String get goHome => 'Volver al inicio';
  @override
  String get pinSaved => 'PIN guardado';
  @override
  String get whoUsesTitle => '¿Quién usa este iPhone?';
  @override
  String get whoUsesBody =>
      'Unspend puede ayudarte a respetar tus propios límites o a cuidar del iPhone de tu hijo o hija.';
  @override
  String get modePersonalTitle => 'Este es mi iPhone';
  @override
  String get modePersonalBody => 'Quiero bloquear apps para mí.';
  @override
  String get modeChildTitle => 'Este es el iPhone de mi hijo o hija';
  @override
  String get modeChildBody =>
      'Soy madre, padre o tutor y decido qué se bloquea.';
  @override
  String get modePersonalShort => 'Yo';
  @override
  String get modeChildShort => 'Mi hijo o hija';
  @override
  String get onboardingBody4Child =>
      'Una madre, un padre o un tutor aprueba Unspend con su cuenta de Apple. Después, tu hijo o hija no podrá eliminar Unspend ni desactivarlo.';
  @override
  String get authNotChildAccount =>
      'Este iPhone no está configurado como dispositivo de un menor. Añade a tu hijo o hija a En Familia en Ajustes o elige «Este es mi iPhone».';
  @override
  String get authConflict =>
      'Otra app ya gestiona Tiempo de uso en este iPhone. Quita primero su acceso en Ajustes › Tiempo de uso.';
  @override
  String get authNetwork =>
      'La aprobación necesita conexión a internet. Inténtalo de nuevo.';
  @override
  String get whoUsesLabel => 'Quién usa este iPhone';
  @override
  String get whoUsesChangeInfo =>
      'Al cambiarlo, se desactiva el acceso de Unspend a Tiempo de uso y se vuelve a solicitar.';
  @override
  String get deactivateAllFirst => 'Desactiva primero todos los perfiles.';
  @override
  String get uninstallProtection => 'Protección contra desinstalación';
  @override
  String get uninstallProtectionBody =>
      'Mientras haya un perfil activo, no se pueden eliminar apps de este iPhone, así que borrar Unspend no sirve para saltarse un bloqueo. iOS solo permite bloquear la eliminación de todas las apps a la vez.';
  @override
  String get stateOn => 'Activado';
  @override
  String get stateOff => 'Desactivado';
  @override
  String tasksProgress(int done, int total) => '$done de $total tareas hechas';
  @override
  String colorName(String id) => switch (id) {
    'Red' => 'Rojo',
    'Orange' => 'Naranja',
    'Amber' => 'Ámbar',
    'Green' => 'Verde',
    'Teal' => 'Turquesa',
    'Blue' => 'Azul',
    'Indigo' => 'Índigo',
    'Purple' => 'Morado',
    'Pink' => 'Rosa',
    _ => id,
  };
  @override
  String iconName(String id) => switch (id) {
    'Social' => 'Social',
    'Games' => 'Juegos',
    'Video' => 'Vídeo',
    'News' => 'Noticias',
    'Shopping' => 'Compras',
    'Chat' => 'Chat',
    'Music' => 'Música',
    'Photos' => 'Fotos',
    'Work' => 'Trabajo',
    'Custom' => 'Personalizado',
    _ => id,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Français ───────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════
class _Fr extends S {
  _Fr() : super._();

  @override
  String get appName => 'Unspend';
  @override
  String get cancel => 'Annuler';
  @override
  String get save => 'Enregistrer';
  @override
  String get delete => 'Supprimer';
  @override
  String get create => 'Créer';
  @override
  String get untitled => 'Sans titre';

  @override
  String get profilesSectionTitle => 'Profils';
  @override
  String get noProfilesYet => 'Aucun profil';
  @override
  String get noProfilesTapPlus =>
      'Appuyez sur + pour créer votre premier profil de blocage.';
  @override
  String get noAppsWarning =>
      'Aucune app dans ce groupe — sélectionnez d\'abord des apps';
  @override
  String get noTasksWarning =>
      'Ajoutez au moins une tâche avant d\'activer le mode tâches';

  @override
  String get allShieldsActive => 'Tous les boucliers actifs';
  @override
  String someShieldsActive(int active, int total) =>
      '$active sur $total actifs';
  @override
  String get noProfiles => 'Aucun profil';
  @override
  String get shieldsInactive => 'Boucliers inactifs';
  @override
  String get blockingDistractingApps => 'Blocage des apps de distraction';
  @override
  String get createProfileToStart => 'Créez un profil pour commencer';
  @override
  String get noProfilesAreActive => 'Aucun profil n\'est actif';

  @override
  String get newProfile => 'Nouveau profil';
  @override
  String get createProfileDescription =>
      'Créez un groupe d\'apps avec ses propres règles de blocage.';
  @override
  String get profileNameHint => 'ex. Réseaux sociaux, Jeux…';

  @override
  String get settings => 'Paramètres';
  @override
  String get changePin => 'Changer le PIN';
  @override
  String get changePinSubtitle =>
      'PIN de désactivation de la personne de confiance';
  @override
  String get languageLabel => 'Langue';
  @override
  String get themeLabel => 'Thème';
  @override
  String get themeSystem => 'Système';
  @override
  String get themeLight => 'Clair';
  @override
  String get themeDark => 'Sombre';

  @override
  String get profileNamePlaceholder => 'Nom du profil';
  @override
  String get sectionColor => 'Couleur';
  @override
  String get sectionIcon => 'Icône';
  @override
  String get sectionApps => 'Apps';
  @override
  String get sectionBlockRules => 'Règles de blocage';
  @override
  String get blockRulesDescription =>
      'Combinez les règles ci-dessous. Sans règle active, utilisez Activer le bouclier pour un contrôle manuel.';
  @override
  String appsSelected(int count) => '$count apps sélectionnées';
  @override
  String get selectAppsToBlock => 'Sélectionner les apps à bloquer';
  @override
  String get tapToChooseApps => 'Touchez pour choisir les apps de ce profil';
  @override
  String get tapToEditSelection => 'Touchez pour voir ou modifier la sélection';
  @override
  String get pickerModeWheel => 'Molette';
  @override
  String get pickerModeKeypad => 'Clavier';
  @override
  String get hoursShort => 'HRS';
  @override
  String get minutesShort => 'MIN';

  @override
  String get scheduleTitle => 'Horaire';
  @override
  String get scheduleDescription =>
      'Blocage strict pendant une plage horaire quotidienne';
  @override
  String get scheduleStart => 'Début';
  @override
  String get scheduleEnd => 'Fin';

  @override
  String get usageLimitTitle => 'Limite d\'utilisation';
  @override
  String get usageLimitDescription =>
      'Blocage souple après un budget quotidien d\'écran';
  @override
  String get dailyLimit => 'Limite quotidienne';

  @override
  String get taskModeTitle => 'Mode tâches';
  @override
  String get taskModeDescription =>
      'Bloquer jusqu\'à ce que toutes les tâches soient terminées';

  @override
  String get activateShield => 'Activer le bouclier';
  @override
  String get deactivateShield => 'Désactiver le bouclier';
  @override
  String get selectAppsToActivate => 'Sélectionner les apps à activer';
  @override
  String get settingsLockedWhileActive =>
      'Les paramètres sont verrouillés tant que le bouclier est actif. Désactivez-le pour modifier.';

  @override
  String get reasonManualMode => 'Mode manuel — désactivez pour débloquer';
  @override
  String get reasonInsideSchedule => 'Dans la plage horaire';
  @override
  String reasonTasksRemaining(int r) =>
      '$r tâche${r == 1 ? '' : 's'} restante${r == 1 ? '' : 's'}';
  @override
  String get reasonAllMet =>
      'Toutes les conditions remplies — apps accessibles';

  @override
  String get noAppsSelected => 'Aucune app sélectionnée';
  @override
  String subtitleApps(int count) => '$count apps';
  @override
  String subtitleUsageLimit(int minutes) => '${minutes}min limite';
  @override
  String subtitleTasks(int done, int total) => '$done/$total tâches';
  @override
  String get subtitleManual => 'Manuel';
  @override
  String subtitleScheduleRange(String start, String end) => '$start–$end';

  @override
  String get deleteProfile => 'Supprimer le profil';
  @override
  String deleteProfileConfirm(String name) =>
      'Supprimer « $name » ? Cette action est irréversible.';

  @override
  String get tasks => 'Tâches';
  @override
  String get addTaskHint => 'Ajouter une tâche…';
  @override
  String get allTasksDoneNote => 'Toutes les tâches terminées !';
  @override
  String tasksRemainingNote(int r) =>
      '$r tâche${r == 1 ? '' : 's'} restante${r == 1 ? '' : 's'} pour débloquer';
  @override
  String get emptyTasksHint =>
      'Ajoutez des tâches à accomplir avant de débloquer les apps.';

  @override
  String get setPinTitle => 'Définir le PIN de désactivation';
  @override
  String get setPinDescription =>
      'Donnez votre téléphone à une personne de confiance.\nElle définit un PIN nécessaire pour désactiver tout bouclier.';
  @override
  String get enterPin => 'Entrer le PIN';
  @override
  String get confirmPin => 'Confirmer le PIN';
  @override
  String get savePin => 'Enregistrer le PIN';
  @override
  String get pinTooShort => 'Le PIN doit comporter au moins 4 caractères';
  @override
  String get pinsMismatch => 'Les PINs ne correspondent pas';

  @override
  String get enterPinToDeactivate => 'Entrer le PIN pour désactiver';
  @override
  String get confirmDeactivation => 'Confirmer la désactivation';
  @override
  String get deactivateAction => 'Désactiver';
  @override
  String get areYouSureDeactivate => 'Êtes-vous sûr de vouloir désactiver ?';
  @override
  String get cooldownDescription =>
      'Prenez un moment pour réfléchir.\nLe bouclier sera désactivable après le minuteur.';
  @override
  String get enterTrustedPersonPin =>
      'Entrez le PIN défini par votre personne de confiance.';
  @override
  String get pinLabel => 'PIN';
  @override
  String get enterYourPin => 'Entrez votre PIN';
  @override
  String get incorrectPin => 'PIN incorrect';
  @override
  String pinLockedOut(int seconds) =>
      'Trop de tentatives. Réessayez dans ${seconds}s';

  @override
  String get privacyPolicyTitle => 'Politique de confidentialité';
  @override
  String get privacyPolicySubtitle => 'Comment vos données sont traitées';
  @override
  String get privacyPolicyBody =>
      'Unspend stocke toutes les données localement sur votre appareil. Aucune donnée personnelle n\'est collectée, transmise ou partagée avec des tiers.\n\n'
      'Vos profils de blocage, paramètres et PIN sont enregistrés dans le stockage de l\'appareil (SharedPreferences et le trousseau iOS). '
      'Aucun service d\'analyse, de suivi ou de télémétrie n\'est utilisé.\n\n'
      'L\'application utilise le framework FamilyControls d\'Apple pour gérer le blocage des apps. Ces données restent sur votre appareil et sont gérées par iOS.\n\n'
      'Vous pouvez supprimer toutes vos données à tout moment depuis Réglages > Supprimer toutes les données.';

  @override
  String get deleteAllData => 'Supprimer toutes les données';
  @override
  String get deleteAllDataSubtitle =>
      'Supprimer tous les profils, le PIN et les réglages';
  @override
  String get deleteAllDataConfirm => 'Tout supprimer';
  @override
  String get deleteAllDataWarning =>
      'Tous les profils, votre PIN et tous les réglages seront définitivement supprimés. Les boucliers actifs seront retirés. Cette action est irréversible.';

  @override
  String get onboardingTitle1 => 'Reprenez votre temps';
  @override
  String get onboardingBody1 =>
      'Unspend vous aide à bloquer les apps distrayantes au niveau du système pour vous concentrer sur l\'essentiel.';
  @override
  String get onboardingTitle2 => 'Créez des profils de blocage';
  @override
  String get onboardingBody2 =>
      'Configurez des profils avec des règles combinables : horaires, limites d\'utilisation quotidienne et déblocage par tâches.';
  @override
  String get onboardingTitle3 => 'Protection incontournable';
  @override
  String get onboardingBody3 =>
      'Les boucliers sont appliqués par iOS lui-même. Un PIN et un minuteur de refroidissement empêchent la désactivation impulsive.';
  @override
  String get getStarted => 'Commencer';
  @override
  String get next => 'Suivant';
  @override
  String get skip => 'Passer';

  // ── v1 hardening ────────────────────────────────────────────────────────
  @override
  String get notNow => 'Plus tard';
  @override
  String get continueLabel => 'Continuer';
  @override
  String get openSettings => 'Ouvrir les Réglages';
  @override
  String get pageNotFound => 'Page introuvable';
  @override
  String get errorTryAgain => 'Une erreur est survenue. Veuillez réessayer.';
  @override
  String get authBannerTitle => 'Accès à Temps d\'écran requis';
  @override
  String get authBannerBody =>
      'Unspend ne peut pas bloquer d\'apps tant que vous n\'autorisez pas l\'accès à Temps d\'écran.';
  @override
  String get authAllow => 'Autoriser l\'accès';
  @override
  String get authDeniedHint =>
      'Si aucune demande n\'apparaît, autorisez l\'accès dans Réglages › Temps d\'écran.';
  @override
  String get authGranted => 'Accès autorisé';
  @override
  String get onboardingTitle4 => 'Autoriser Temps d\'écran';
  @override
  String get onboardingBody4 =>
      'Unspend utilise Temps d\'écran d\'Apple pour bloquer les apps que vous choisissez. Votre sélection ne quitte jamais cet appareil.';
  @override
  String get reasonLimitReached => 'Limite quotidienne atteinte';
  @override
  String get errorNotAuthorized =>
      'L\'accès à Temps d\'écran n\'a pas encore été autorisé.';
  @override
  String get errorScheduleTooShort =>
      'L\'horaire doit durer au moins 15 minutes.';
  @override
  String get errorTooManyActivities =>
      'Trop de profils sont actifs en même temps. Désactivez-en un et réessayez.';
  @override
  String get deactivationFailed =>
      'Impossible de lever le blocage. Veuillez réessayer.';
  @override
  String get cooldownGeneric =>
      'Prenez un moment pour réfléchir.\nVous pourrez continuer à la fin du minuteur.';
  @override
  String get pickerTitle => 'Choisir des apps';
  @override
  String get pickerTooManyApps =>
      'Vous pouvez choisir jusqu\'à 50 apps individuelles. Choisissez des catégories entières pour en bloquer davantage.';
  @override
  String get shieldTitleTemplate => 'Bloqué : {app}';
  @override
  String get shieldSubtitleTemplate => 'Bloqué par « {profile} » dans Unspend';
  @override
  String get shieldSubtitleGeneric => 'Bloqué par Unspend';
  @override
  String get shieldButton => 'Retour';
  @override
  String get shieldAppFallback => 'Cette app';
  @override
  String get shieldWebsiteFallback => 'Ce site web';
  @override
  String get showPin => 'Afficher le PIN';
  @override
  String get hidePin => 'Masquer le PIN';
  @override
  String get statusActive => 'Actif';
  @override
  String get statusInactive => 'Inactif';
  @override
  String get addTask => 'Ajouter une tâche';
  @override
  String deleteTaskLabel(String title) => 'Supprimer la tâche « $title »';
  @override
  String get errorUnavailable =>
      'Temps d’écran n’est pas disponible sur cet appareil.';
  @override
  String get goHome => 'Retour à l’accueil';
  @override
  String get pinSaved => 'PIN enregistré';
  @override
  String get whoUsesTitle => 'Qui utilise cet iPhone ?';
  @override
  String get whoUsesBody =>
      'Unspend peut vous aider à tenir vos propres limites ou à veiller sur l’iPhone de votre enfant.';
  @override
  String get modePersonalTitle => 'C’est mon iPhone';
  @override
  String get modePersonalBody => 'Je veux bloquer des apps pour moi-même.';
  @override
  String get modeChildTitle => 'C’est l’iPhone de mon enfant';
  @override
  String get modeChildBody =>
      'Je suis parent ou tuteur et je décide de ce qui est bloqué.';
  @override
  String get modePersonalShort => 'Moi';
  @override
  String get modeChildShort => 'Mon enfant';
  @override
  String get onboardingBody4Child =>
      'Un parent ou tuteur approuve Unspend avec son compte Apple. Ensuite, votre enfant ne peut ni supprimer Unspend ni le désactiver.';
  @override
  String get authNotChildAccount =>
      'Cet iPhone n’est pas configuré comme l’appareil d’un enfant. Ajoutez votre enfant au Partage familial dans Réglages ou choisissez « C’est mon iPhone ».';
  @override
  String get authConflict =>
      'Une autre app gère déjà Temps d’écran sur cet iPhone. Retirez d’abord son accès dans Réglages › Temps d’écran.';
  @override
  String get authNetwork =>
      'L’approbation nécessite une connexion internet. Veuillez réessayer.';
  @override
  String get whoUsesLabel => 'Qui utilise cet iPhone';
  @override
  String get whoUsesChangeInfo =>
      'Ce changement désactive l’accès d’Unspend à Temps d’écran, puis le redemande.';
  @override
  String get deactivateAllFirst => 'Désactivez d’abord tous les profils.';
  @override
  String get uninstallProtection => 'Protection contre la suppression';
  @override
  String get uninstallProtectionBody =>
      'Tant qu’un profil est actif, aucune app ne peut être supprimée de cet iPhone : supprimer Unspend ne permet donc pas de contourner un blocage. iOS ne peut verrouiller la suppression que pour toutes les apps à la fois.';
  @override
  String get stateOn => 'Activé';
  @override
  String get stateOff => 'Désactivé';
  @override
  String tasksProgress(int done, int total) =>
      '$done sur $total tâches terminées';
  @override
  String colorName(String id) => switch (id) {
    'Red' => 'Rouge',
    'Orange' => 'Orange',
    'Amber' => 'Ambre',
    'Green' => 'Vert',
    'Teal' => 'Turquoise',
    'Blue' => 'Bleu',
    'Indigo' => 'Indigo',
    'Purple' => 'Violet',
    'Pink' => 'Rose',
    _ => id,
  };
  @override
  String iconName(String id) => switch (id) {
    'Social' => 'Social',
    'Games' => 'Jeux',
    'Video' => 'Vidéo',
    'News' => 'Actualités',
    'Shopping' => 'Achats',
    'Chat' => 'Discussion',
    'Music' => 'Musique',
    'Photos' => 'Photos',
    'Work' => 'Travail',
    'Custom' => 'Personnalisé',
    _ => id,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Hrvatski (Croatian) ────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════
class _Hr extends S {
  _Hr() : super._();

  @override
  String get appName => 'Unspend';
  @override
  String get cancel => 'Odustani';
  @override
  String get save => 'Spremi';
  @override
  String get delete => 'Obriši';
  @override
  String get create => 'Kreiraj';
  @override
  String get untitled => 'Bez naziva';

  @override
  String get profilesSectionTitle => 'Profili';
  @override
  String get noProfilesYet => 'Nema profila';
  @override
  String get noProfilesTapPlus =>
      'Dodirni + za izradu prvog profila za blokiranje.';
  @override
  String get noAppsWarning =>
      'Nema aplikacija u ovoj grupi — prvo odaberi aplikacije';
  @override
  String get noTasksWarning =>
      'Dodaj barem jedan zadatak prije aktiviranja načina zadataka';

  @override
  String get allShieldsActive => 'Svi štitovi aktivni';
  @override
  String someShieldsActive(int active, int total) =>
      '$active od $total aktivno';
  @override
  String get noProfiles => 'Nema profila';
  @override
  String get shieldsInactive => 'Štitovi neaktivni';
  @override
  String get blockingDistractingApps => 'Blokiranje ometajućih aplikacija';
  @override
  String get createProfileToStart => 'Kreiraj profil za početak';
  @override
  String get noProfilesAreActive => 'Nijedan profil nije aktivan';

  @override
  String get newProfile => 'Novi profil';
  @override
  String get createProfileDescription =>
      'Kreiraj grupu aplikacija s vlastitim pravilima blokiranja.';
  @override
  String get profileNameHint => 'npr. Društvene mreže, Igre…';

  @override
  String get settings => 'Postavke';
  @override
  String get changePin => 'Promijeni PIN';
  @override
  String get changePinSubtitle => 'PIN za deaktivaciju osobe od povjerenja';
  @override
  String get languageLabel => 'Jezik';
  @override
  String get themeLabel => 'Tema';
  @override
  String get themeSystem => 'Sustav';
  @override
  String get themeLight => 'Svijetla';
  @override
  String get themeDark => 'Tamna';

  @override
  String get profileNamePlaceholder => 'Naziv profila';
  @override
  String get sectionColor => 'Boja';
  @override
  String get sectionIcon => 'Ikona';
  @override
  String get sectionApps => 'Aplikacije';
  @override
  String get sectionBlockRules => 'Pravila blokiranja';
  @override
  String get blockRulesDescription =>
      'Kombiniraj pravila. Bez aktivnih pravila koristi Aktiviraj štit za ručnu kontrolu.';
  @override
  String appsSelected(int count) => '$count aplikacija odabrano';
  @override
  String get selectAppsToBlock => 'Odaberi aplikacije za blokiranje';
  @override
  String get tapToChooseApps => 'Dodirni za odabir aplikacija za ovaj profil';
  @override
  String get tapToEditSelection => 'Dodirni za pregled ili promjenu odabira';
  @override
  String get pickerModeWheel => 'Kotač';
  @override
  String get pickerModeKeypad => 'Tipke';
  @override
  String get hoursShort => 'SATI';
  @override
  String get minutesShort => 'MIN';

  @override
  String get scheduleTitle => 'Raspored';
  @override
  String get scheduleDescription =>
      'Čvrsto blokiranje unutar dnevnog vremenskog okvira';
  @override
  String get scheduleStart => 'Početak';
  @override
  String get scheduleEnd => 'Kraj';

  @override
  String get usageLimitTitle => 'Ograničenje korištenja';
  @override
  String get usageLimitDescription =>
      'Meko blokiranje nakon dnevnog budžeta zaslona';
  @override
  String get dailyLimit => 'Dnevno ograničenje';

  @override
  String get taskModeTitle => 'Način zadataka';
  @override
  String get taskModeDescription => 'Blokiraj dok se svi zadaci ne dovrše';

  @override
  String get activateShield => 'Aktiviraj štit';
  @override
  String get deactivateShield => 'Deaktiviraj štit';
  @override
  String get selectAppsToActivate => 'Odaberi aplikacije za aktiviranje';
  @override
  String get settingsLockedWhileActive =>
      'Postavke su zaključane dok je štit aktivan. Deaktiviraj ga za promjene.';

  @override
  String get reasonManualMode => 'Ručni način — deaktiviraj za otključavanje';
  @override
  String get reasonInsideSchedule => 'Unutar vremenskog okvira';
  @override
  String reasonTasksRemaining(int r) => 'Još $r zadat${r == 1 ? 'ak' : 'aka'}';
  @override
  String get reasonAllMet => 'Svi uvjeti ispunjeni — aplikacije dostupne';

  @override
  String get noAppsSelected => 'Nema odabranih aplikacija';
  @override
  String subtitleApps(int count) => '$count aplikacija';
  @override
  String subtitleUsageLimit(int minutes) => '${minutes}min ograničenje';
  @override
  String subtitleTasks(int done, int total) => '$done/$total zadataka';
  @override
  String get subtitleManual => 'Ručno';
  @override
  String subtitleScheduleRange(String start, String end) => '$start–$end';

  @override
  String get deleteProfile => 'Obriši profil';
  @override
  String deleteProfileConfirm(String name) =>
      'Obrisati „$name"? Ovo se ne može poništiti.';

  @override
  String get tasks => 'Zadaci';
  @override
  String get addTaskHint => 'Dodaj zadatak…';
  @override
  String get allTasksDoneNote => 'Svi zadaci dovršeni!';
  @override
  String tasksRemainingNote(int r) =>
      'Još $r zadat${r == 1 ? 'ak' : 'aka'} za otključavanje';
  @override
  String get emptyTasksHint =>
      'Dodaj zadatke koji moraju biti završeni prije otključavanja aplikacija.';

  @override
  String get setPinTitle => 'Postavi PIN za deaktivaciju';
  @override
  String get setPinDescription =>
      'Daj telefon osobi od povjerenja.\nOna postavlja PIN potreban za deaktivaciju bilo kojeg štita.';
  @override
  String get enterPin => 'Unesi PIN';
  @override
  String get confirmPin => 'Potvrdi PIN';
  @override
  String get savePin => 'Spremi PIN';
  @override
  String get pinTooShort => 'PIN mora imati najmanje 4 znaka';
  @override
  String get pinsMismatch => 'PIN-ovi se ne podudaraju';

  @override
  String get enterPinToDeactivate => 'Unesi PIN za deaktivaciju';
  @override
  String get confirmDeactivation => 'Potvrdi deaktivaciju';
  @override
  String get deactivateAction => 'Deaktiviraj';
  @override
  String get areYouSureDeactivate =>
      'Jesi li siguran/na da želiš deaktivirati?';
  @override
  String get cooldownDescription =>
      'Uzmi trenutak za razmišljanje.\nŠtit će se moći deaktivirati nakon timera.';
  @override
  String get enterTrustedPersonPin =>
      'Unesi PIN koji je postavila tvoja osoba od povjerenja.';
  @override
  String get pinLabel => 'PIN';
  @override
  String get enterYourPin => 'Unesi svoj PIN';
  @override
  String get incorrectPin => 'Netočan PIN';
  @override
  String pinLockedOut(int seconds) =>
      'Previše pokušaja. Pokušaj za ${seconds}s';

  @override
  String get privacyPolicyTitle => 'Politika privatnosti';
  @override
  String get privacyPolicySubtitle => 'Kako se rukuje tvojim podacima';
  @override
  String get privacyPolicyBody =>
      'Unspend pohranjuje sve podatke lokalno na tvom uređaju. Nikakvi osobni podaci se ne prikupljaju, prenose ili dijele s trećim stranama.\n\n'
      'Tvoji profili blokiranja, postavke i PIN se pohranjuju pomoću lokalne pohrane (SharedPreferences i iOS Keychain). '
      'Ne koriste se nikakve analitike, praćenje ili telemetrija.\n\n'
      'Aplikacija koristi Appleov FamilyControls okvir za upravljanje blokiranjem aplikacija. Ti podaci ostaju na tvom uređaju i njima upravlja isključivo iOS.\n\n'
      'Možeš obrisati sve podatke u bilo kojem trenutku iz Postavki > Obriši sve podatke.';

  @override
  String get deleteAllData => 'Obriši sve podatke';
  @override
  String get deleteAllDataSubtitle => 'Ukloni sve profile, PIN i postavke';
  @override
  String get deleteAllDataConfirm => 'Obriši sve';
  @override
  String get deleteAllDataWarning =>
      'Ovo će trajno obrisati sve profile, tvoj PIN i sve postavke. Aktivni štitovi će biti uklonjeni. Ovo se ne može poništiti.';

  @override
  String get onboardingTitle1 => 'Preuzmi kontrolu nad vremenom';
  @override
  String get onboardingBody1 =>
      'Unspend ti pomaže blokirati aplikacije koje odvlače pažnju na razini OS-a kako bi se mogao/la fokusirati na ono što je važno.';
  @override
  String get onboardingTitle2 => 'Izradi profile blokiranja';
  @override
  String get onboardingBody2 =>
      'Postavi profile s kombinabilnim pravilima: vremenski rasporedi, dnevna ograničenja korištenja i otključavanje na temelju zadataka.';
  @override
  String get onboardingTitle3 => 'Zaštita koju ne možeš preskočiti';
  @override
  String get onboardingBody3 =>
      'Štitove primjenjuje sam iOS. PIN i tajmer hlađenja sprječavaju impulzivno isključivanje.';
  @override
  String get getStarted => 'Počni';
  @override
  String get next => 'Dalje';
  @override
  String get skip => 'Preskoči';

  // ── v1 hardening ────────────────────────────────────────────────────────
  @override
  String get notNow => 'Ne sada';
  @override
  String get continueLabel => 'Nastavi';
  @override
  String get openSettings => 'Otvori Postavke';
  @override
  String get pageNotFound => 'Stranica nije pronađena';
  @override
  String get errorTryAgain => 'Nešto je pošlo po zlu. Pokušaj ponovno.';
  @override
  String get authBannerTitle => 'Potreban je pristup Vremenu uporabe zaslona';
  @override
  String get authBannerBody =>
      'Unspend ne može blokirati aplikacije dok ne dopustiš pristup Vremenu uporabe zaslona.';
  @override
  String get authAllow => 'Dopusti pristup';
  @override
  String get authDeniedHint =>
      'Ako se upit ne pojavi, dopusti pristup u Postavke › Vrijeme uporabe zaslona.';
  @override
  String get authGranted => 'Pristup dopušten';
  @override
  String get onboardingTitle4 => 'Dopusti Vrijeme uporabe zaslona';
  @override
  String get onboardingBody4 =>
      'Unspend koristi Appleovo Vrijeme uporabe zaslona za blokiranje aplikacija koje odabereš. Tvoj odabir nikada ne napušta ovaj uređaj.';
  @override
  String get reasonLimitReached => 'Dnevno ograničenje dosegnuto';
  @override
  String get errorNotAuthorized =>
      'Pristup Vremenu uporabe zaslona još nije dopušten.';
  @override
  String get errorScheduleTooShort =>
      'Raspored mora trajati najmanje 15 minuta.';
  @override
  String get errorTooManyActivities =>
      'Previše je profila aktivno istovremeno. Deaktiviraj jedan i pokušaj ponovno.';
  @override
  String get deactivationFailed =>
      'Blokadu nije bilo moguće ukloniti. Pokušaj ponovno.';
  @override
  String get cooldownGeneric =>
      'Uzmi trenutak da razmisliš.\nMoći ćeš nastaviti kad odbrojavanje završi.';
  @override
  String get pickerTitle => 'Odaberi aplikacije';
  @override
  String get pickerTooManyApps =>
      'Možeš odabrati do 50 pojedinačnih aplikacija. Odaberi cijele kategorije da blokiraš više.';
  @override
  String get shieldTitleTemplate => 'Blokirano: {app}';
  @override
  String get shieldSubtitleTemplate => 'Blokira profil „{profile}“ u Unspendu';
  @override
  String get shieldSubtitleGeneric => 'Blokira Unspend';
  @override
  String get shieldButton => 'Natrag';
  @override
  String get shieldAppFallback => 'Ova aplikacija';
  @override
  String get shieldWebsiteFallback => 'Ova web-stranica';
  @override
  String get showPin => 'Prikaži PIN';
  @override
  String get hidePin => 'Sakrij PIN';
  @override
  String get statusActive => 'Aktivno';
  @override
  String get statusInactive => 'Neaktivno';
  @override
  String get addTask => 'Dodaj zadatak';
  @override
  String deleteTaskLabel(String title) => 'Obriši zadatak „$title“';
  @override
  String get errorUnavailable =>
      'Vrijeme uporabe zaslona nije dostupno na ovom uređaju.';
  @override
  String get goHome => 'Natrag na početak';
  @override
  String get pinSaved => 'PIN spremljen';
  @override
  String get whoUsesTitle => 'Tko koristi ovaj iPhone?';
  @override
  String get whoUsesBody =>
      'Unspend ti pomaže držati se vlastitih granica ili brinuti o iPhoneu svog djeteta.';
  @override
  String get modePersonalTitle => 'Ovo je moj iPhone';
  @override
  String get modePersonalBody => 'Želim blokirati aplikacije za sebe.';
  @override
  String get modeChildTitle => 'Ovo je iPhone mog djeteta';
  @override
  String get modeChildBody =>
      'Roditelj sam ili skrbnik i odlučujem što se blokira.';
  @override
  String get modePersonalShort => 'Ja';
  @override
  String get modeChildShort => 'Moje dijete';
  @override
  String get onboardingBody4Child =>
      'Roditelj ili skrbnik odobrava Unspend svojim Apple računom. Nakon toga dijete ne može obrisati niti isključiti Unspend.';
  @override
  String get authNotChildAccount =>
      'Ovaj iPhone nije postavljen kao dječji uređaj. Dodaj dijete u Dijeljenje s obitelji u Postavkama ili odaberi „Ovo je moj iPhone“.';
  @override
  String get authConflict =>
      'Druga aplikacija već upravlja Vremenom uporabe zaslona na ovom iPhoneu. Najprije joj ukloni pristup u Postavke › Vrijeme uporabe zaslona.';
  @override
  String get authNetwork =>
      'Za odobrenje je potrebna internetska veza. Pokušaj ponovno.';
  @override
  String get whoUsesLabel => 'Tko koristi ovaj iPhone';
  @override
  String get whoUsesChangeInfo =>
      'Promjenom se pristup Unspenda Vremenu uporabe zaslona isključuje i ponovno traži.';
  @override
  String get deactivateAllFirst => 'Najprije deaktiviraj sve profile.';
  @override
  String get uninstallProtection => 'Zaštita od brisanja';
  @override
  String get uninstallProtectionBody =>
      'Dok je profil aktivan, aplikacije se ne mogu brisati s ovog iPhonea, pa brisanje Unspenda nije način za zaobilaženje blokade. iOS može zaključati brisanje samo za sve aplikacije odjednom.';
  @override
  String get stateOn => 'Uključeno';
  @override
  String get stateOff => 'Isključeno';
  @override
  String tasksProgress(int done, int total) =>
      '$done od $total zadataka dovršeno';
  @override
  String colorName(String id) => switch (id) {
    'Red' => 'Crvena',
    'Orange' => 'Narančasta',
    'Amber' => 'Jantarna',
    'Green' => 'Zelena',
    'Teal' => 'Tirkizna',
    'Blue' => 'Plava',
    'Indigo' => 'Indigo',
    'Purple' => 'Ljubičasta',
    'Pink' => 'Ružičasta',
    _ => id,
  };
  @override
  String iconName(String id) => switch (id) {
    'Social' => 'Društvene mreže',
    'Games' => 'Igre',
    'Video' => 'Video',
    'News' => 'Vijesti',
    'Shopping' => 'Kupovina',
    'Chat' => 'Razgovor',
    'Music' => 'Glazba',
    'Photos' => 'Fotografije',
    'Work' => 'Posao',
    'Custom' => 'Prilagođeno',
    _ => id,
  };
}
