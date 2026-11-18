package com.maxroth.backyourtime

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent
import com.maxroth.backyourtime.core.Blocker
import com.maxroth.backyourtime.core.DayKey
import com.maxroth.backyourtime.core.ShieldPolicy
import java.time.LocalDateTime

/**
 * Notices which app comes to the front and puts the block screen over it
 * when an active profile blocks it. Also counts the time spent in apps
 * with a daily limit.
 *
 * It is an accessibility service because that is how Android tells an app
 * about the app in front. It only receives "a window opened" events with
 * the app's name; it cannot read what is on screen
 * (`canRetrieveWindowContent` is off) and nothing leaves the phone.
 *
 * The rules are asked at the moment an app opens, and again every few
 * seconds while an app covered by a profile stays open — so a schedule
 * that starts, a budget that runs out or the midnight reset take effect
 * without the app being reopened.
 */
class BlockerService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private val store by lazy { sharedStore() }

    /** The app in front, as far as the events tell. */
    private var foreground: String? = null

    /** When usage of [foreground] was last accounted for; 0 while not counting. */
    private var countingSince = 0L

    private var protectedPackages: Set<String> = emptySet()
    private var protectedReadAt = 0L

    /** The app the block screen was last put over, and when. */
    private var lastBlocked: String? = null
    private var lastBlockedAt = 0L

    /** Whether a window class is an activity, per "package/class". */
    private val activityCache = HashMap<String, Boolean>()

    private val tick = Runnable {
        settleUsage()
        evaluate()
    }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    settleUsage()
                    stopCounting()
                }
                Intent.ACTION_USER_PRESENT -> evaluate()
            }
        }
    }

    override fun onServiceConnected() {
        instance = this
        registerReceiver(
            screenReceiver,
            IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(Intent.ACTION_USER_PRESENT)
            },
        )
        store.log("service: connected", LocalDateTime.now())
    }

    override fun onUnbind(intent: Intent?): Boolean {
        shutDown()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        shutDown()
        super.onDestroy()
    }

    private fun shutDown() {
        if (instance !== this) return
        instance = null
        settleUsage()
        stopCounting()
        try {
            unregisterReceiver(screenReceiver)
        } catch (_: IllegalArgumentException) {
            // Was never registered.
        }
        store.log("service: disconnected", LocalDateTime.now())
    }

    override fun onInterrupt() = Unit

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val packageName = event.packageName?.toString() ?: return
        // Dialogs, the keyboard and the notification shade open windows too;
        // only an activity means a different app is in front.
        if (!isActivity(packageName, event.className?.toString())) return

        settleUsage()
        foreground = packageName
        evaluate()
    }

    /** Blocks the app in front if a profile says so; otherwise keeps watching it. */
    private fun evaluate() {
        val packageName = foreground ?: return
        val now = LocalDateTime.now()
        val profiles = store.activeProfiles(now)

        if (packageName == this.packageName || !Blocker.isWatched(packageName, profiles) ||
            packageName in currentProtectedPackages()
        ) {
            stopCounting()
            return
        }

        val blocking = Blocker.blockingProfile(packageName, profiles, now)
        if (blocking != null) {
            stopCounting()
            // An app often opens two windows in a row (splash, then its
            // first screen); one block screen is enough.
            val elapsedRealtime = SystemClock.elapsedRealtime()
            if (packageName == lastBlocked && elapsedRealtime - lastBlockedAt < REPEAT_MILLIS) return
            lastBlocked = packageName
            lastBlockedAt = elapsedRealtime
            store.log("block ${blocking.id.takeLast(ID_TAIL)}: $packageName", now)
            startActivity(BlockActivity.intent(this, packageName, blocking.rules.name))
            return
        }

        // Covered by a profile but open for now: look again shortly.
        if (countingSince == 0L) countingSince = SystemClock.elapsedRealtime()
        handler.removeCallbacks(tick)
        handler.postDelayed(tick, TICK_MILLIS)
    }

    /** Adds the time since the last look to the budgets it counts against. */
    private fun settleUsage() {
        val packageName = foreground ?: return
        if (countingSince == 0L) return
        val elapsedRealtime = SystemClock.elapsedRealtime()
        // A tick can be late (the phone dozed); never count more than two.
        val seconds = ((elapsedRealtime - countingSince) / 1000).coerceIn(0, 2 * TICK_MILLIS / 1000)
        if (seconds == 0L) return
        countingSince += seconds * 1000

        val now = LocalDateTime.now()
        val today = DayKey.string(now)
        for (profile in Blocker.meteredProfiles(packageName, store.activeProfiles(now), now)) {
            val total = store.addUsage(profile.id, today, seconds)
            if (ShieldPolicy.isLimitReached(profile.rules, total)) {
                store.log("limit ${profile.id.takeLast(ID_TAIL)}: reached", now)
            }
        }
    }

    private fun stopCounting() {
        countingSince = 0
        handler.removeCallbacks(tick)
    }

    private fun isActivity(packageName: String, className: String?): Boolean {
        if (className == null) return false
        return activityCache.getOrPut("$packageName/$className") {
            try {
                packageManager.getActivityInfo(ComponentName(packageName, className), 0)
                true
            } catch (_: PackageManager.NameNotFoundException) {
                false
            }
        }
    }

    /** Re-read now and then: the default launcher or phone app can change. */
    private fun currentProtectedPackages(): Set<String> {
        val elapsedRealtime = SystemClock.elapsedRealtime()
        if (protectedReadAt == 0L || elapsedRealtime - protectedReadAt > PROTECTED_MAX_AGE_MILLIS) {
            protectedPackages = InstalledApps.protectedPackages(this)
            protectedReadAt = elapsedRealtime
        }
        return protectedPackages
    }

    companion object {
        /** How often an open, covered app is looked at again. */
        private const val TICK_MILLIS = 10_000L
        private const val PROTECTED_MAX_AGE_MILLIS = 60_000L

        /** Window events of one app this close together are one launch. */
        private const val REPEAT_MILLIS = 1_000L
        private const val ID_TAIL = 6

        /** The running service, if the user has switched it on. */
        @Volatile
        var instance: BlockerService? = null
            private set

        /** Asks the rules again for the app in front, after they changed. */
        fun reevaluate() {
            val service = instance ?: return
            service.handler.post {
                service.settleUsage()
                service.evaluate()
            }
        }

        /** Switches the service off, as if the user had done it in Settings. */
        fun disable() {
            instance?.disableSelf()
        }
    }
}
