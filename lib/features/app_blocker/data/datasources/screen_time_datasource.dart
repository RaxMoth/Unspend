import '../../domain/entities/blocker_profile.dart';

/// Whether the user has granted Screen Time access.
enum ScreenTimeAuthStatus { notDetermined, denied, approved }

/// Who Screen Time access is requested for.
enum ScreenTimeMember {
  /// The person using the phone approves for themselves, and can withdraw
  /// the approval in Settings.
  individual,

  /// A parent or guardian approves, with their Apple Account, on a child's
  /// phone in Family Sharing. iOS then keeps the child from deleting the app
  /// or withdrawing its access.
  child,
}

/// Why an action on a profile was refused.
enum ScreenTimeError {
  /// Screen Time access has not been granted.
  notAuthorized,

  /// The profile has no apps, categories or websites selected.
  noSelection,

  /// More individually picked apps or websites than iOS can shield.
  tooManyApps,

  /// The schedule is shorter than the 15 minutes iOS requires.
  scheduleTooShort,

  /// iOS refuses to monitor more activities at once.
  tooManyActivities,

  /// Task mode is on but the profile has no tasks.
  taskModeNeedsTasks,

  /// The profile is active; the action is only allowed while inactive.
  profileActive,

  /// Screen Time is not available here (not iOS, or misconfigured build).
  unavailable,

  /// Access was requested for a child, but the phone is not signed in as a
  /// child in Family Sharing.
  notChildAccount,

  /// Another app already holds Screen Time access that conflicts with ours.
  authorizationConflict,

  /// Approving access needs an internet connection.
  network,

  /// Anything else; see [ScreenTimeException.message].
  unknown,
}

class ScreenTimeException implements Exception {
  const ScreenTimeException(this.error, [this.message]);

  final ScreenTimeError error;
  final String? message;

  @override
  String toString() => message == null
      ? 'ScreenTimeException(${error.name})'
      : 'ScreenTimeException(${error.name}: $message)';
}

/// What the OS reports for one active profile.
class ShieldStatus {
  const ShieldStatus({required this.shielded, required this.limitReachedToday});

  /// The profile's apps are blocked right now.
  final bool shielded;

  /// The profile's daily usage limit has been used up today.
  final bool limitReachedToday;

  @override
  bool operator ==(Object other) =>
      other is ShieldStatus &&
      other.shielded == shielded &&
      other.limitReachedToday == limitReachedToday;

  @override
  int get hashCode => Object.hash(shielded, limitReachedToday);

  @override
  String toString() =>
      'ShieldStatus(shielded: $shielded, limitReachedToday: $limitReachedToday)';
}

/// The rules the OS should enforce for a profile from now on.
class ActivationRequest {
  const ActivationRequest({
    required this.profileId,
    required this.name,
    this.scheduleStartMinute,
    this.scheduleEndMinute,
    this.usageLimitMinutes,
    this.taskModeEnabled = false,
    this.tasksDone = false,
  });

  /// Only the rules that are switched on are sent; a rule that is off is
  /// simply absent.
  factory ActivationRequest.fromProfile(BlockerProfile profile) =>
      ActivationRequest(
        profileId: profile.id,
        name: profile.name,
        scheduleStartMinute: profile.hasSchedule
            ? profile.scheduleStartMinuteOfDay
            : null,
        scheduleEndMinute: profile.hasSchedule
            ? profile.scheduleEndMinuteOfDay
            : null,
        usageLimitMinutes: profile.usageLimitEnabled
            ? profile.usageLimitMinutes
            : null,
        taskModeEnabled: profile.taskModeEnabled,
        tasksDone: profile.taskModeEnabled && profile.allTasksDone,
      );

  final String profileId;

  /// Shown on the shield screen.
  final String name;

  /// Schedule window as minutes of the day (0–1439); both or neither.
  final int? scheduleStartMinute;
  final int? scheduleEndMinute;

  final int? usageLimitMinutes;
  final bool taskModeEnabled;

  /// Whether today's tasks are already complete.
  final bool tasksDone;

  bool get hasSchedule =>
      scheduleStartMinute != null && scheduleEndMinute != null;

  bool get isManualOnly =>
      !hasSchedule && usageLimitMinutes == null && !taskModeEnabled;

  Map<String, Object?> toMap() => {
    'profileId': profileId,
    'name': name,
    'scheduleStartMinute': ?scheduleStartMinute,
    'scheduleEndMinute': ?scheduleEndMinute,
    'usageLimitMinutes': ?usageLimitMinutes,
    'taskModeEnabled': taskModeEnabled,
    'tasksDone': tasksDone,
  };

  @override
  bool operator ==(Object other) =>
      other is ActivationRequest &&
      other.profileId == profileId &&
      other.name == name &&
      other.scheduleStartMinute == scheduleStartMinute &&
      other.scheduleEndMinute == scheduleEndMinute &&
      other.usageLimitMinutes == usageLimitMinutes &&
      other.taskModeEnabled == taskModeEnabled &&
      other.tasksDone == tasksDone;

  @override
  int get hashCode => Object.hash(
    profileId,
    name,
    scheduleStartMinute,
    scheduleEndMinute,
    usageLimitMinutes,
    taskModeEnabled,
    tasksDone,
  );

  @override
  String toString() => 'ActivationRequest(${toMap()})';
}

/// A profile the app shows as active, sent with every sync so the OS side
/// can be brought back in line with the app.
class ActiveProfileState {
  const ActiveProfileState({required this.profileId, required this.tasksDone});

  final String profileId;

  /// Whether today's tasks are complete (false when task mode is off).
  final bool tasksDone;

  Map<String, Object?> toMap() => {
    'profileId': profileId,
    'tasksDone': tasksDone,
  };
}

/// Text for the system app picker sheet.
class AppPickerLabels {
  const AppPickerLabels({
    required this.title,
    required this.cancel,
    required this.save,
    required this.tooMany,
  });

  final String title;
  final String cancel;
  final String save;

  /// Shown when more apps are picked than iOS can shield individually.
  final String tooMany;

  Map<String, Object?> toMap() => {
    'title': title,
    'cancel': cancel,
    'save': save,
    'tooMany': tooMany,
  };
}

/// Text for the screen iOS shows instead of a blocked app.
class ShieldStrings {
  const ShieldStrings({
    required this.titleTemplate,
    required this.subtitleTemplate,
    required this.subtitleGeneric,
    required this.button,
    required this.appFallback,
    required this.websiteFallback,
  });

  /// `{app}` is replaced with the blocked app or website.
  final String titleTemplate;

  /// `{profile}` is replaced with the blocking profile's name.
  final String subtitleTemplate;
  final String subtitleGeneric;
  final String button;
  final String appFallback;
  final String websiteFallback;

  Map<String, Object?> toMap() => {
    'titleTemplate': titleTemplate,
    'subtitleTemplate': subtitleTemplate,
    'subtitleGeneric': subtitleGeneric,
    'button': button,
    'appFallback': appFallback,
    'websiteFallback': websiteFallback,
  };

  @override
  bool operator ==(Object other) =>
      other is ShieldStrings &&
      other.titleTemplate == titleTemplate &&
      other.subtitleTemplate == subtitleTemplate &&
      other.subtitleGeneric == subtitleGeneric &&
      other.button == button &&
      other.appFallback == appFallback &&
      other.websiteFallback == websiteFallback;

  @override
  int get hashCode => Object.hash(
    titleTemplate,
    subtitleTemplate,
    subtitleGeneric,
    button,
    appFallback,
    websiteFallback,
  );
}

/// What the OS side knows, for the debug-only diagnostics screen.
class ScreenTimeDiagnostics {
  const ScreenTimeDiagnostics({
    required this.authorization,
    this.removalLocked = false,
    this.activeProfileIds = const [],
    this.shieldedProfileIds = const [],
    this.monitoredActivities = const [],
    this.eventLog = const [],
  });

  final ScreenTimeAuthStatus authorization;

  /// Whether deleting apps is locked right now.
  final bool removalLocked;
  final List<String> activeProfileIds;
  final List<String> shieldedProfileIds;
  final List<String> monitoredActivities;

  /// Most recent rule evaluations by the app and its extension, oldest first.
  final List<String> eventLog;
}

/// Everything the app asks of iOS Screen Time.
///
/// The calls state intents; how they map onto shields and monitors is the
/// native side's business. Every call may throw a [ScreenTimeException].
abstract interface class ScreenTimeDatasource {
  Future<ScreenTimeAuthStatus> authorizationStatus();

  /// Shows the system permission prompt if the user has not decided yet.
  ///
  /// Throws a [ScreenTimeException] with [ScreenTimeError.notChildAccount],
  /// [ScreenTimeError.authorizationConflict] or [ScreenTimeError.network]
  /// when iOS gives one of those reasons for not asking.
  Future<ScreenTimeAuthStatus> requestAuthorization({
    required ScreenTimeMember member,
  });

  /// Gives Screen Time access back so it can be requested again, for example
  /// for a different [ScreenTimeMember]. Refused while a profile is active.
  Future<void> revokeAuthorization();

  /// Opens this app's page in the Settings app.
  Future<void> openSettings();

  /// Shows the system app picker for [profileId]. Returns the number of
  /// selected items, or null when the user cancelled.
  Future<int?> pickApps({
    required String profileId,
    required AppPickerLabels labels,
  });

  /// Starts enforcing the profile's rules.
  Future<ShieldStatus> activate(ActivationRequest request);

  /// Stops enforcing the profile's rules and lifts its block.
  Future<void> deactivate(String profileId);

  /// Tells the OS whether today's tasks of an active profile are complete.
  Future<ShieldStatus> setTasksDone(String profileId, {required bool done});

  /// Re-evaluates every active profile and reports its status. Profiles
  /// missing from the result are no longer enforced by the OS.
  Future<Map<String, ShieldStatus>> sync(List<ActiveProfileState> active);

  /// Lifts the profile's block and forgets its app selection.
  Future<void> deleteProfile(String profileId);

  /// Lifts every block and removes everything stored on the OS side.
  Future<void> resetAll(List<String> profileIds);

  /// Switches uninstall protection on or off. While it is on, apps cannot
  /// be deleted from the phone as long as a profile is active.
  Future<void> setRemovalLockEnabled(bool enabled);

  /// Sets the text of the shield screen (in the app's current language).
  Future<void> setShieldStrings(ShieldStrings strings);

  Future<ScreenTimeDiagnostics> diagnostics();
}
