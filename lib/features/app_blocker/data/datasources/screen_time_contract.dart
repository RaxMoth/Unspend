/// The wire contract with the native side: channel names, method names,
/// argument and reply keys, error codes.
///
/// Every name here exists once more in Swift (`ChannelContract` in
/// `ios/Runner/ScreenTimeChannel.swift`). Change both together;
/// `test/data/method_channel_screen_time_datasource_test.dart` pins the
/// Dart half with literal strings so a typo here fails a test.
library;

abstract final class ScreenTimeChannels {
  static const screenTime = 'com.maxroth.backyourtime/screentime';
  static const appPicker = 'com.maxroth.backyourtime/apppicker';
}

abstract final class ScreenTimeMethod {
  static const authorizationStatus = 'authorizationStatus';
  static const requestAuthorization = 'requestAuthorization';
  static const revokeAuthorization = 'revokeAuthorization';
  static const openSettings = 'openSettings';
  static const activate = 'activate';
  static const deactivate = 'deactivate';
  static const setTasksDone = 'setTasksDone';
  static const sync = 'sync';
  static const deleteProfile = 'deleteProfile';
  static const resetAll = 'resetAll';
  static const setShieldStrings = 'setShieldStrings';
  static const setRemovalLockEnabled = 'setRemovalLockEnabled';
  static const diagnostics = 'diagnostics';
  static const appVersion = 'appVersion';

  /// On the app-picker channel.
  static const showPicker = 'showPicker';
}

abstract final class ScreenTimeArg {
  static const profileId = 'profileId';
  static const profileIds = 'profileIds';
  static const profiles = 'profiles';
  static const member = 'member';
  static const enabled = 'enabled';
  static const done = 'done';

  // Rules of a profile being activated.
  static const name = 'name';
  static const scheduleStartMinute = 'scheduleStartMinute';
  static const scheduleEndMinute = 'scheduleEndMinute';
  static const usageLimitMinutes = 'usageLimitMinutes';
  static const taskModeEnabled = 'taskModeEnabled';
  static const tasksDone = 'tasksDone';

  // Labels of the app picker.
  static const title = 'title';
  static const cancel = 'cancel';
  static const save = 'save';
  static const tooMany = 'tooMany';

  // Text of the shield screen.
  static const titleTemplate = 'titleTemplate';
  static const subtitleTemplate = 'subtitleTemplate';
  static const subtitleGeneric = 'subtitleGeneric';
  static const button = 'button';
  static const appFallback = 'appFallback';
  static const websiteFallback = 'websiteFallback';
}

abstract final class ScreenTimeReply {
  // Status of one profile.
  static const shielded = 'shielded';
  static const limitReached = 'limitReached';

  // Authorization status values.
  static const approved = 'approved';
  static const denied = 'denied';

  // Diagnostics.
  static const authorization = 'authorization';
  static const removalLocked = 'removalLocked';
  static const activeProfileIds = 'activeProfileIds';
  static const shieldedProfileIds = 'shieldedProfileIds';
  static const monitoredActivities = 'monitoredActivities';
  static const eventLog = 'eventLog';
}

abstract final class ScreenTimeErrorCode {
  static const notAuthorized = 'NOT_AUTHORIZED';
  static const noSelection = 'NO_SELECTION';
  static const tooManyApps = 'TOO_MANY_APPS';
  static const scheduleTooShort = 'SCHEDULE_TOO_SHORT';
  static const tooManyActivities = 'TOO_MANY_ACTIVITIES';
  static const profileActive = 'PROFILE_ACTIVE';
  static const noAppGroup = 'NO_APP_GROUP';
  static const notChildAccount = 'NOT_CHILD_ACCOUNT';
  static const authorizationConflict = 'AUTH_CONFLICT';
  static const network = 'NETWORK';
}
