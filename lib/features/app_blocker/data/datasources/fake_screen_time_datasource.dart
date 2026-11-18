import '../../../../core/time/day_key.dart';
import '../../domain/shield_policy.dart';
import 'screen_time_datasource.dart';

/// In-memory stand-in for iOS Screen Time.
///
/// It applies the same rule as the native side, so the app behaves
/// realistically in the Simulator (`main_dev.dart`) and tests can check both
/// the calls that were made and the resulting block state.
class FakeScreenTimeDatasource implements ScreenTimeDatasource {
  FakeScreenTimeDatasource({
    this.authStatus = ScreenTimeAuthStatus.approved,
    this.statusAfterRequest = ScreenTimeAuthStatus.approved,
    this.isChildAccount = true,
    this.pickCount = 3,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// Current answer of [authorizationStatus].
  ScreenTimeAuthStatus authStatus;

  /// What the user "answers" when the permission prompt is shown.
  ScreenTimeAuthStatus statusAfterRequest;

  /// Whether the phone is signed in as a child in Family Sharing. When it
  /// is not, access cannot be requested for a child.
  bool isChildAccount;

  /// Who access was last granted for.
  ScreenTimeMember? authorizedMember;

  /// The uninstall-protection setting.
  bool removalLockEnabled = true;

  /// Whether deleting apps is locked right now.
  bool get removalLocked => removalLockEnabled && active.isNotEmpty;

  /// What the picker returns; null means the user cancels.
  int? pickCount;

  /// When set, the next call that can fail throws this once.
  ScreenTimeException? failNext;

  /// When set, the next call that can fail throws this once — anything at
  /// all, to exercise how the app copes with a failure nobody anticipated.
  Object? crashNext;

  /// Every call in order, e.g. `activate:<id>`, `setTasksDone:<id>:true`.
  final List<String> calls = [];

  /// Number of picked items per profile.
  final Map<String, int> selections = {};

  /// The rules currently enforced, per active profile.
  final Map<String, ActivationRequest> active = {};

  final Map<String, String> _tasksDoneDay = {};
  final Map<String, String> _limitReachedDay = {};

  ShieldStrings? shieldStrings;
  AppPickerLabels? lastPickerLabels;
  bool settingsOpened = false;

  /// Simulates the monitor extension reporting that today's usage limit of
  /// [profileId] has been used up.
  void reachLimit(String profileId) =>
      _limitReachedDay[profileId] = dayKey(_clock());

  /// Whether the profile's apps would be blocked right now.
  bool isShielded(String profileId) => _status(profileId).shielded;

  void _failIfRequested() {
    final crash = crashNext;
    if (crash != null) {
      crashNext = null;
      // Deliberately not an Error or Exception subtype: that is the point.
      // ignore: only_throw_errors
      throw crash;
    }
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  ShieldStatus _status(String profileId) {
    final rules = active[profileId];
    if (rules == null) {
      return const ShieldStatus(shielded: false, limitReachedToday: false);
    }
    final now = _clock();
    final today = dayKey(now);
    final limitReached =
        rules.usageLimitMinutes != null && _limitReachedDay[profileId] == today;
    final shielded = ShieldPolicy.shouldShield(
      manualOnly: rules.isManualOnly,
      insideScheduleWindow:
          rules.hasSchedule &&
          ShieldPolicy.isInsideWindow(
            minuteOfDay: now.hour * 60 + now.minute,
            startMinute: rules.scheduleStartMinute!,
            endMinute: rules.scheduleEndMinute!,
          ),
      tasksPending: rules.taskModeEnabled && _tasksDoneDay[profileId] != today,
      limitReachedToday: limitReached,
    );
    return ShieldStatus(shielded: shielded, limitReachedToday: limitReached);
  }

  void _forget(String profileId) {
    active.remove(profileId);
    _tasksDoneDay.remove(profileId);
    _limitReachedDay.remove(profileId);
  }

  @override
  Future<ScreenTimeAuthStatus> authorizationStatus() async => authStatus;

  @override
  Future<ScreenTimeAuthStatus> requestAuthorization({
    required ScreenTimeMember member,
  }) async {
    calls.add('requestAuthorization:${member.name}');
    _failIfRequested();
    if (member == ScreenTimeMember.child && !isChildAccount) {
      throw const ScreenTimeException(ScreenTimeError.notChildAccount);
    }
    if (authStatus == ScreenTimeAuthStatus.notDetermined) {
      authStatus = statusAfterRequest;
    }
    if (authStatus == ScreenTimeAuthStatus.approved) {
      authorizedMember ??= member;
    }
    return authStatus;
  }

  @override
  Future<void> revokeAuthorization() async {
    calls.add('revokeAuthorization');
    _failIfRequested();
    if (active.isNotEmpty) {
      throw const ScreenTimeException(ScreenTimeError.profileActive);
    }
    authStatus = ScreenTimeAuthStatus.notDetermined;
    authorizedMember = null;
  }

  @override
  Future<void> setRemovalLockEnabled(bool enabled) async {
    calls.add('setRemovalLockEnabled:$enabled');
    _failIfRequested();
    removalLockEnabled = enabled;
  }

  @override
  Future<void> openSettings() async {
    calls.add('openSettings');
    settingsOpened = true;
  }

  @override
  Future<int?> pickApps({
    required String profileId,
    required AppPickerLabels labels,
  }) async {
    calls.add('pickApps:$profileId');
    lastPickerLabels = labels;
    _failIfRequested();
    if (active.containsKey(profileId)) {
      throw const ScreenTimeException(ScreenTimeError.profileActive);
    }
    final count = pickCount;
    if (count != null) selections[profileId] = count;
    return count;
  }

  @override
  Future<ShieldStatus> activate(ActivationRequest request) async {
    calls.add('activate:${request.profileId}');
    _failIfRequested();
    if (authStatus != ScreenTimeAuthStatus.approved) {
      throw const ScreenTimeException(ScreenTimeError.notAuthorized);
    }
    if ((selections[request.profileId] ?? 0) == 0) {
      throw const ScreenTimeException(ScreenTimeError.noSelection);
    }
    _forget(request.profileId);
    active[request.profileId] = request;
    if (request.taskModeEnabled && request.tasksDone) {
      _tasksDoneDay[request.profileId] = dayKey(_clock());
    }
    return _status(request.profileId);
  }

  @override
  Future<void> deactivate(String profileId) async {
    calls.add('deactivate:$profileId');
    _failIfRequested();
    _forget(profileId);
  }

  @override
  Future<ShieldStatus> setTasksDone(
    String profileId, {
    required bool done,
  }) async {
    calls.add('setTasksDone:$profileId:$done');
    _failIfRequested();
    if (active.containsKey(profileId)) {
      if (done) {
        _tasksDoneDay[profileId] = dayKey(_clock());
      } else {
        _tasksDoneDay.remove(profileId);
      }
    }
    return _status(profileId);
  }

  @override
  Future<Map<String, ShieldStatus>> sync(
    List<ActiveProfileState> profiles,
  ) async {
    calls.add('sync:${profiles.map((p) => p.profileId).join(',')}');
    _failIfRequested();
    final expected = {for (final p in profiles) p.profileId: p.tasksDone};
    for (final id in active.keys.toList()) {
      if (!expected.containsKey(id)) _forget(id);
    }
    final today = dayKey(_clock());
    final statuses = <String, ShieldStatus>{};
    for (final entry in active.entries) {
      if (entry.value.taskModeEnabled && expected[entry.key]!) {
        _tasksDoneDay[entry.key] = today;
      } else {
        _tasksDoneDay.remove(entry.key);
      }
      statuses[entry.key] = _status(entry.key);
    }
    return statuses;
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    calls.add('deleteProfile:$profileId');
    _failIfRequested();
    _forget(profileId);
    selections.remove(profileId);
  }

  @override
  Future<void> resetAll(List<String> profileIds) async {
    calls.add('resetAll');
    _failIfRequested();
    active.clear();
    selections.clear();
    _tasksDoneDay.clear();
    _limitReachedDay.clear();
    shieldStrings = null;
    removalLockEnabled = true;
  }

  @override
  Future<void> setShieldStrings(ShieldStrings strings) async {
    calls.add('setShieldStrings');
    shieldStrings = strings;
  }

  @override
  Future<ScreenTimeDiagnostics> diagnostics() async => ScreenTimeDiagnostics(
    authorization: authStatus,
    removalLocked: removalLocked,
    activeProfileIds: active.keys.toList(),
    shieldedProfileIds: active.keys.where(isShielded).toList(),
    monitoredActivities: [
      for (final rules in active.values) ...[
        if (rules.hasSchedule) 'unspend.schedule.${rules.profileId}',
        if (rules.usageLimitMinutes != null || rules.taskModeEnabled)
          'unspend.day.${rules.profileId}',
      ],
    ],
    eventLog: List.of(calls),
  );
}
