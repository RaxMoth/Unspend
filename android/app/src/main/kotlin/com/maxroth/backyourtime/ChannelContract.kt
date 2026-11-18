package com.maxroth.backyourtime

/**
 * The wire contract with Dart: channel names, method names, argument and
 * reply keys, error codes.
 *
 * Every name here exists once more in Dart
 * (`lib/features/app_blocker/data/datasources/screen_time_contract.dart`)
 * and in Swift (`ios/Runner/ChannelContract.swift`). Change all three
 * together.
 */
object ChannelContract {
    const val SCREEN_TIME_CHANNEL = "com.maxroth.backyourtime/screentime"
    const val APP_PICKER_CHANNEL = "com.maxroth.backyourtime/apppicker"

    object Method {
        const val AUTHORIZATION_STATUS = "authorizationStatus"
        const val REQUEST_AUTHORIZATION = "requestAuthorization"
        const val REVOKE_AUTHORIZATION = "revokeAuthorization"
        const val OPEN_SETTINGS = "openSettings"
        const val ACTIVATE = "activate"
        const val DEACTIVATE = "deactivate"
        const val SET_TASKS_DONE = "setTasksDone"
        const val SYNC = "sync"
        const val DELETE_PROFILE = "deleteProfile"
        const val RESET_ALL = "resetAll"
        const val SET_SHIELD_STRINGS = "setShieldStrings"
        const val SET_REMOVAL_LOCK_ENABLED = "setRemovalLockEnabled"
        const val DIAGNOSTICS = "diagnostics"
        const val APP_VERSION = "appVersion"

        /** On the app-picker channel. */
        const val SHOW_PICKER = "showPicker"
    }

    object Arg {
        const val PROFILE_ID = "profileId"
        const val PROFILE_IDS = "profileIds"
        const val PROFILES = "profiles"
        const val DONE = "done"

        // Rules of a profile being activated.
        const val NAME = "name"
        const val SCHEDULE_START_MINUTE = "scheduleStartMinute"
        const val SCHEDULE_END_MINUTE = "scheduleEndMinute"
        const val USAGE_LIMIT_MINUTES = "usageLimitMinutes"
        const val TASK_MODE_ENABLED = "taskModeEnabled"
        const val TASKS_DONE = "tasksDone"

        // Labels of the app picker.
        const val TITLE = "title"
        const val CANCEL = "cancel"
        const val SAVE = "save"
    }

    object Reply {
        // Status of one profile.
        const val SHIELDED = "shielded"
        const val LIMIT_REACHED = "limitReached"

        // Authorization status values.
        const val APPROVED = "approved"
        const val DENIED = "denied"
        const val NOT_DETERMINED = "notDetermined"

        // Diagnostics.
        const val AUTHORIZATION = "authorization"
        const val REMOVAL_LOCKED = "removalLocked"
        const val ACTIVE_PROFILE_IDS = "activeProfileIds"
        const val SHIELDED_PROFILE_IDS = "shieldedProfileIds"
        const val MONITORED_ACTIVITIES = "monitoredActivities"
        const val EVENT_LOG = "eventLog"
    }

    object ErrorCode {
        const val NOT_AUTHORIZED = "NOT_AUTHORIZED"
        const val NO_SELECTION = "NO_SELECTION"
        const val SCHEDULE_TOO_SHORT = "SCHEDULE_TOO_SHORT"
        const val PROFILE_ACTIVE = "PROFILE_ACTIVE"

        // Reported to Dart as "something went wrong".
        const val INVALID_ARGS = "INVALID_ARGS"
        const val FAILED = "MONITOR_FAILED"
    }
}
