package com.maxroth.backyourtime

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.maxroth.backyourtime.ChannelContract.Arg
import com.maxroth.backyourtime.ChannelContract.ErrorCode
import com.maxroth.backyourtime.ChannelContract.Method
import com.maxroth.backyourtime.ChannelContract.Reply
import com.maxroth.backyourtime.core.DayKey
import com.maxroth.backyourtime.core.ProfileRules
import com.maxroth.backyourtime.core.ShieldPolicy
import com.maxroth.backyourtime.core.ShieldStrings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.LocalDateTime
import java.util.concurrent.Executors

/**
 * The Android end of the bridge to Dart.
 *
 * It answers the same calls as `ScreenTimeChannel.swift`, so the Dart side
 * does not know which platform it is talking to. What differs is how a
 * block is enforced: here the rules are stored and [BlockerService] asks
 * them whenever an app comes to the front.
 *
 * Not offered on Android: uninstall protection and the child's-phone mode
 * (the calls are accepted and change nothing) and blocking websites.
 */
class ScreenTimeChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val store = activity.sharedStore()
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /** Dart is waiting for the user to come back from the system settings. */
    private var pendingAccess: MethodChannel.Result? = null

    /** Dart is waiting for the app picker to close. */
    private var pendingPick: MethodChannel.Result? = null

    init {
        MethodChannel(messenger, ChannelContract.SCREEN_TIME_CHANNEL).setMethodCallHandler(this)
        MethodChannel(messenger, ChannelContract.APP_PICKER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == Method.SHOW_PICKER) showPicker(call, result) else result.notImplemented()
        }
    }

    private class ChannelException(val code: String, message: String) : Exception(message)

    // --- Dispatch -----------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            Method.AUTHORIZATION_STATUS -> result.success(authorizationStatus())
            Method.REQUEST_AUTHORIZATION -> requestAuthorization(result)
            Method.REVOKE_AUTHORIZATION -> revokeAuthorization(result)
            Method.OPEN_SETTINGS -> result.success(openAccessSettings())
            Method.APP_VERSION -> result.success(appVersion())

            Method.ACTIVATE, Method.DEACTIVATE, Method.SET_TASKS_DONE, Method.SYNC,
            Method.DELETE_PROFILE, Method.RESET_ALL, Method.SET_SHIELD_STRINGS,
            Method.SET_REMOVAL_LOCK_ENABLED, Method.DIAGNOSTICS,
            -> worker.execute {
                val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                try {
                    val reply = perform(call.method, args)
                    main.post { result.success(reply) }
                } catch (e: ChannelException) {
                    main.post { result.error(e.code, e.message, null) }
                } catch (e: Exception) {
                    main.post { result.error(ErrorCode.FAILED, e.message, null) }
                }
            }

            else -> result.notImplemented()
        }
    }

    /** The calls that read or write the store. Runs on the worker thread. */
    private fun perform(method: String, args: Map<*, *>): Any = when (method) {
        Method.ACTIVATE -> activate(args)
        Method.DEACTIVATE -> {
            deactivate(profileId(args), "deactivate")
            true
        }
        Method.SET_TASKS_DONE -> setTasksDone(profileId(args), args[Arg.DONE] == true)
        Method.SYNC -> sync(args)
        Method.DELETE_PROFILE -> {
            val id = profileId(args)
            deactivate(id, "delete")
            store.removeProfile(id)
            true
        }
        Method.RESET_ALL -> {
            store.removeEverything()
            (args[Arg.PROFILE_IDS] as? List<*>)?.filterIsInstance<String>()?.forEach(store::removeProfile)
            BlockerService.reevaluate()
            true
        }
        Method.SET_SHIELD_STRINGS -> {
            store.shieldStrings = ShieldStrings.fromMap(args)
                ?: throw ChannelException(ErrorCode.INVALID_ARGS, "Incomplete shield strings")
            true
        }
        // Uninstall protection does not exist on Android.
        Method.SET_REMOVAL_LOCK_ENABLED -> true
        Method.DIAGNOSTICS -> diagnostics()
        else -> throw ChannelException(ErrorCode.INVALID_ARGS, "Unknown method $method")
    }

    private fun profileId(args: Map<*, *>): String =
        (args[Arg.PROFILE_ID] as? String)?.takeIf { it.isNotEmpty() }
            ?: throw ChannelException(ErrorCode.INVALID_ARGS, "Missing profileId")

    private fun Map<*, *>.int(key: String): Int? = (this[key] as? Number)?.toInt()

    // --- Access -------------------------------------------------------------

    private fun authorizationStatus(): String = when {
        BlockerAccess.isEnabled(activity) -> Reply.APPROVED
        store.accessRequested -> Reply.DENIED
        else -> Reply.NOT_DETERMINED
    }

    /**
     * Sends the user to the system screen where the blocker service is
     * switched on, and answers when they come back. Android has no prompt
     * for this; the app explains what to do before calling.
     */
    private fun requestAuthorization(result: MethodChannel.Result) {
        if (BlockerAccess.isEnabled(activity)) {
            result.success(Reply.APPROVED)
            return
        }
        store.accessRequested = true
        pendingAccess?.success(authorizationStatus())
        pendingAccess = result
        if (!openAccessSettings()) {
            pendingAccess = null
            result.success(Reply.DENIED)
        }
    }

    private fun openAccessSettings(): Boolean = try {
        activity.startActivity(BlockerAccess.settingsIntent())
        true
    } catch (_: ActivityNotFoundException) {
        false
    }

    /** The user is back in the app. */
    fun onResume() {
        pendingAccess?.success(authorizationStatus())
        pendingAccess = null
    }

    /** Switches the blocker service off again. Refused while a profile is active. */
    private fun revokeAuthorization(result: MethodChannel.Result) {
        if (store.activeProfileIds.isNotEmpty()) {
            result.error(ErrorCode.PROFILE_ACTIVE, "Deactivate every profile first", null)
            return
        }
        BlockerService.disable()
        result.success(true)
    }

    // --- App picker ---------------------------------------------------------

    private fun showPicker(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
        val id = (args[Arg.PROFILE_ID] as? String)?.takeIf { it.isNotEmpty() }
        if (id == null) {
            result.error(ErrorCode.INVALID_ARGS, "Missing profileId", null)
            return
        }
        if (id in store.activeProfileIds) {
            result.error(ErrorCode.PROFILE_ACTIVE, "The profile is active", null)
            return
        }
        pendingPick?.success(null)
        pendingPick = result
        activity.startActivityForResult(
            AppPickerActivity.intent(
                activity,
                profileId = id,
                title = args[Arg.TITLE] as? String,
                cancel = args[Arg.CANCEL] as? String,
                save = args[Arg.SAVE] as? String,
            ),
            REQUEST_PICK_APPS,
        )
    }

    /** The app picker closed: the number of chosen apps, or null if cancelled. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_PICK_APPS) return
        val count = data?.getIntExtra(AppPickerActivity.EXTRA_COUNT, 0)
        pendingPick?.success(if (resultCode == Activity.RESULT_OK) count else null)
        pendingPick = null
    }

    // --- Activation ---------------------------------------------------------

    private fun activate(args: Map<*, *>): Map<String, Any> {
        val id = profileId(args)
        if (!BlockerAccess.isEnabled(activity)) {
            throw ChannelException(ErrorCode.NOT_AUTHORIZED, "The blocker service is switched off")
        }
        if (store.selection(id).isEmpty()) {
            throw ChannelException(ErrorCode.NO_SELECTION, "No apps selected")
        }
        val now = LocalDateTime.now()
        val rules = makeRules(args, now)

        // The budget counts from now on, not from earlier today.
        store.clearUsage(id)
        store.saveRules(id, rules)
        store.setActive(id, true)

        val status = status(id, now)
        val state = if (status[Reply.SHIELDED] == true) "shielded" else "armed"
        store.log("activate ${id.takeLast(ID_TAIL)}: $state", now)
        BlockerService.reevaluate()
        return status
    }

    private fun makeRules(args: Map<*, *>, now: LocalDateTime): ProfileRules {
        var rules = ProfileRules(
            name = args[Arg.NAME] as? String ?: "",
            taskModeEnabled = args[Arg.TASK_MODE_ENABLED] == true,
        )
        val start = args.int(Arg.SCHEDULE_START_MINUTE)
        val end = args.int(Arg.SCHEDULE_END_MINUTE)
        if (start != null && end != null) {
            val valid = 0 until ShieldPolicy.MINUTES_PER_DAY
            if (start !in valid || end !in valid) {
                throw ChannelException(ErrorCode.INVALID_ARGS, "Schedule times are out of range")
            }
            if (!ShieldPolicy.isValidSchedule(start, end)) {
                throw ChannelException(ErrorCode.SCHEDULE_TOO_SHORT, "The schedule is too short")
            }
            rules = rules.copy(scheduleStartMinute = start, scheduleEndMinute = end)
        }
        args.int(Arg.USAGE_LIMIT_MINUTES)?.let { limit ->
            if (limit !in 1 until ShieldPolicy.MINUTES_PER_DAY) {
                throw ChannelException(ErrorCode.INVALID_ARGS, "Usage limit is out of range")
            }
            rules = rules.copy(usageLimitMinutes = limit)
        }
        if (rules.taskModeEnabled && args[Arg.TASKS_DONE] == true) {
            rules = rules.copy(tasksDoneDay = DayKey.string(now))
        }
        return rules
    }

    private fun deactivate(profileId: String, reason: String) {
        if (profileId in store.activeProfileIds) {
            store.log("$reason ${profileId.takeLast(ID_TAIL)}", LocalDateTime.now())
        }
        store.removeActivation(profileId)
        BlockerService.reevaluate()
    }

    // --- Tasks --------------------------------------------------------------

    private fun setTasksDone(profileId: String, done: Boolean): Map<String, Any> {
        val now = LocalDateTime.now()
        store.rules(profileId)?.let { rules ->
            store.saveRules(profileId, rules.copy(tasksDoneDay = if (done) DayKey.string(now) else null))
            store.log("tasks ${profileId.takeLast(ID_TAIL)}: ${if (done) "done" else "pending"}", now)
            BlockerService.reevaluate()
        }
        return status(profileId, now)
    }

    // --- Sync ---------------------------------------------------------------

    /**
     * Brings the native side in line with what the app believes and reports
     * back. Anything active here but unknown to the app is switched off;
     * anything the app lists that cannot be enforced any more is left out of
     * the reply, so the app shows it as inactive.
     */
    private fun sync(args: Map<*, *>): Map<String, Any> {
        val tasksDone = HashMap<String, Boolean>()
        for (entry in args[Arg.PROFILES] as? List<*> ?: emptyList<Any>()) {
            val map = entry as? Map<*, *> ?: continue
            val id = map[Arg.PROFILE_ID] as? String ?: continue
            tasksDone[id] = map[Arg.TASKS_DONE] == true
        }

        val now = LocalDateTime.now()
        val today = DayKey.string(now)
        val reply = HashMap<String, Any>()
        for (id in store.activeProfileIds) {
            val done = tasksDone[id]
            val rules = store.rules(id)
            if (done == null || rules == null || store.selection(id).isEmpty()) {
                store.removeActivation(id)
                store.log("sync ${id.takeLast(ID_TAIL)}: switched off, not enforceable", now)
                continue
            }
            val doneDay = if (rules.taskModeEnabled && done) today else null
            if (rules.tasksDoneDay != doneDay) store.saveRules(id, rules.copy(tasksDoneDay = doneDay))
            reply[id] = status(id, now)
        }
        BlockerService.reevaluate()
        return reply
    }

    private fun status(profileId: String, now: LocalDateTime): Map<String, Any> {
        val rules = store.rules(profileId)
        val used = store.usedSeconds(profileId, DayKey.string(now))
        return mapOf(
            Reply.SHIELDED to (rules != null && ShieldPolicy.shouldShield(rules, used, now)),
            Reply.LIMIT_REACHED to (rules != null && ShieldPolicy.isLimitReached(rules, used)),
        )
    }

    // --- Diagnostics --------------------------------------------------------

    private fun appVersion(): String = try {
        val info = activity.packageManager.getPackageInfo(activity.packageName, 0)
        val build = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
        "${info.versionName} ($build)"
    } catch (_: Exception) {
        ""
    }

    private fun diagnostics(): Map<String, Any> {
        val now = LocalDateTime.now()
        val today = DayKey.string(now)
        val active = store.activeProfileIds
        val profiles = store.activeProfiles(now)
        val service = if (BlockerService.instance != null) "running" else "not running"
        return mapOf(
            Reply.AUTHORIZATION to authorizationStatus(),
            Reply.REMOVAL_LOCKED to false,
            Reply.ACTIVE_PROFILE_IDS to active,
            Reply.SHIELDED_PROFILE_IDS to profiles.filter { it.isShielded(now) }.map { it.id },
            // What Android watches instead of iOS's monitors.
            Reply.MONITORED_ACTIVITIES to listOf("blocker service: $service") +
                profiles.filter { it.rules.hasUsageLimit }.map {
                    val used = store.usedSeconds(it.id, today) / 60
                    "limit ${it.id.takeLast(ID_TAIL)}: $used of ${it.rules.usageLimitMinutes} min used"
                },
            Reply.EVENT_LOG to store.eventLog,
        )
    }

    companion object {
        private const val REQUEST_PICK_APPS = 4201
        private const val ID_TAIL = 6
    }
}
