import Flutter

/// The wire contract with Dart: channel names, method names, argument and
/// reply keys, error codes.
///
/// Every name here exists once more in Dart
/// (`lib/features/app_blocker/data/datasources/screen_time_contract.dart`)
/// and in Kotlin (`android/app/src/main/kotlin/.../ChannelContract.kt`).
/// Change all three together.
enum ChannelContract {
    static let screenTimeChannel = "com.maxroth.backyourtime/screentime"
    static let appPickerChannel = "com.maxroth.backyourtime/apppicker"

    /// Label of the queue Screen Time work runs on.
    static let workQueueLabel = "com.maxroth.backyourtime.screentime"

    enum Method: String {
        case authorizationStatus
        case requestAuthorization
        case revokeAuthorization
        case openSettings
        case activate
        case deactivate
        case setTasksDone
        case sync
        case deleteProfile
        case resetAll
        case setShieldStrings
        case setRemovalLockEnabled
        case diagnostics
        case appVersion

        /// On the app-picker channel.
        case showPicker
    }

    enum Arg {
        static let profileId = "profileId"
        static let profileIds = "profileIds"
        static let profiles = "profiles"
        static let member = "member"
        static let memberChild = "child"
        static let enabled = "enabled"
        static let done = "done"

        // Rules of a profile being activated.
        static let name = "name"
        static let scheduleStartMinute = "scheduleStartMinute"
        static let scheduleEndMinute = "scheduleEndMinute"
        static let usageLimitMinutes = "usageLimitMinutes"
        static let taskModeEnabled = "taskModeEnabled"
        static let tasksDone = "tasksDone"

        // Labels of the app picker.
        static let title = "title"
        static let cancel = "cancel"
        static let save = "save"
        static let tooMany = "tooMany"
    }

    enum Reply {
        // Status of one profile.
        static let shielded = "shielded"
        static let limitReached = "limitReached"

        // Authorization status values.
        static let approved = "approved"
        static let denied = "denied"
        static let notDetermined = "notDetermined"

        // Diagnostics.
        static let authorization = "authorization"
        static let removalLocked = "removalLocked"
        static let activeProfileIds = "activeProfileIds"
        static let shieldedProfileIds = "shieldedProfileIds"
        static let monitoredActivities = "monitoredActivities"
        static let eventLog = "eventLog"
    }

    enum ErrorCode: String {
        case notAuthorized = "NOT_AUTHORIZED"
        case noSelection = "NO_SELECTION"
        case tooManyApps = "TOO_MANY_APPS"
        case scheduleTooShort = "SCHEDULE_TOO_SHORT"
        case tooManyActivities = "TOO_MANY_ACTIVITIES"
        case profileActive = "PROFILE_ACTIVE"
        case noAppGroup = "NO_APP_GROUP"
        case notChildAccount = "NOT_CHILD_ACCOUNT"
        case authorizationConflict = "AUTH_CONFLICT"
        case network = "NETWORK"

        // Reported to Dart as "something went wrong".
        case monitorFailed = "MONITOR_FAILED"
        case invalidArgs = "INVALID_ARGS"
        case revokeFailed = "REVOKE_FAILED"
        case noWindow = "NO_ROOT_VC"

        func error(_ message: String) -> FlutterError {
            FlutterError(code: rawValue, message: message, details: nil)
        }
    }
}
