package com.maxroth.backyourtime.core

import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.time.LocalDateTime
import java.util.Locale

/** What [SharedStore] keeps its values in: preferences in the app, a map in tests. */
interface KeyValueStore {
    fun getString(key: String): String?

    /** Stores [value], or removes the key when it is null. */
    fun putString(key: String, value: String?)

    fun keys(): Set<String>
}

/** A [KeyValueStore] in memory. */
class MemoryKeyValueStore : KeyValueStore {
    private val values = mutableMapOf<String, String>()

    override fun getString(key: String): String? = values[key]

    override fun putString(key: String, value: String?) {
        if (value == null) values.remove(key) else values[key] = value
    }

    override fun keys(): Set<String> = values.keys.toSet()
}

/** Time spent in a profile's apps on one day. */
data class Usage(val day: String, val seconds: Long)

/**
 * Everything the native side remembers: which apps a profile covers, the
 * rules of the active profiles, how much of today's budget is used.
 *
 * The bridge (on its worker thread) and the blocker service (on the main
 * thread) both use it, so every operation holds one lock. Mirrors
 * `SharedStore.swift`; the Dart side never reads these values directly.
 */
class SharedStore(private val values: KeyValueStore) {

    // --- Selection (package names) ---------------------------------------

    fun selection(profileId: String): Set<String> = synchronized(LOCK) {
        strings(values.getString(SELECTION_PREFIX + profileId)).toSet()
    }

    fun setSelection(profileId: String, packages: Set<String>) = synchronized(LOCK) {
        values.putString(SELECTION_PREFIX + profileId, JSONArray(packages.sorted()).toString())
    }

    // --- Rules ------------------------------------------------------------

    fun rules(profileId: String): ProfileRules? = synchronized(LOCK) {
        values.getString(RULES_PREFIX + profileId)?.let(ProfileRules::fromJson)
    }

    fun saveRules(profileId: String, rules: ProfileRules) = synchronized(LOCK) {
        values.putString(RULES_PREFIX + profileId, rules.toJson())
    }

    // --- Active profiles --------------------------------------------------

    val activeProfileIds: List<String>
        get() = synchronized(LOCK) { strings(values.getString(ACTIVE_PROFILE_IDS)) }

    fun setActive(profileId: String, active: Boolean) = synchronized(LOCK) {
        val ids = activeProfileIds.filter { it != profileId }.toMutableList()
        if (active) ids.add(profileId)
        values.putString(ACTIVE_PROFILE_IDS, JSONArray(ids).toString())
    }

    /**
     * The active profiles that can be enforced: those with rules and at
     * least one app.
     */
    fun activeProfiles(now: LocalDateTime): List<ActiveProfile> = synchronized(LOCK) {
        val today = DayKey.string(now)
        activeProfileIds.mapNotNull { id ->
            val rules = rules(id) ?: return@mapNotNull null
            val packages = selection(id)
            if (packages.isEmpty()) return@mapNotNull null
            ActiveProfile(id, rules, packages, usedSeconds(id, today))
        }
    }

    // --- Usage ------------------------------------------------------------

    /** Seconds spent in the profile's apps on [day]; zero on any other day. */
    fun usedSeconds(profileId: String, day: String): Long = synchronized(LOCK) {
        usage(profileId)?.takeIf { it.day == day }?.seconds ?: 0
    }

    /** Adds [seconds] to the profile's usage on [day] and returns the total. */
    fun addUsage(profileId: String, day: String, seconds: Long): Long = synchronized(LOCK) {
        val total = usedSeconds(profileId, day) + seconds.coerceAtLeast(0)
        values.putString(
            USAGE_PREFIX + profileId,
            JSONObject().put(USAGE_DAY, day).put(USAGE_SECONDS, total).toString(),
        )
        total
    }

    fun clearUsage(profileId: String) = synchronized(LOCK) {
        values.putString(USAGE_PREFIX + profileId, null)
    }

    private fun usage(profileId: String): Usage? {
        val json = values.getString(USAGE_PREFIX + profileId) ?: return null
        return try {
            val o = JSONObject(json)
            Usage(o.getString(USAGE_DAY), o.getLong(USAGE_SECONDS))
        } catch (_: JSONException) {
            null
        }
    }

    // --- Block screen text -------------------------------------------------

    var shieldStrings: ShieldStrings
        get() = synchronized(LOCK) {
            values.getString(SHIELD_STRINGS)?.let(ShieldStrings::fromJson) ?: ShieldStrings.english
        }
        set(strings) = synchronized(LOCK) { values.putString(SHIELD_STRINGS, strings.toJson()) }

    // --- Access -----------------------------------------------------------

    /**
     * Whether the user has been sent to the system settings to allow access
     * before. Tells "not asked yet" from "asked, and it is off".
     */
    var accessRequested: Boolean
        get() = synchronized(LOCK) { values.getString(ACCESS_REQUESTED) == TRUE }
        set(requested) = synchronized(LOCK) {
            values.putString(ACCESS_REQUESTED, if (requested) TRUE else null)
        }

    // --- Removal ----------------------------------------------------------

    /**
     * Forgets that a profile is active: rules, usage and membership. The
     * app selection is kept so the profile can be activated again.
     */
    fun removeActivation(profileId: String) = synchronized(LOCK) {
        values.putString(RULES_PREFIX + profileId, null)
        values.putString(USAGE_PREFIX + profileId, null)
        setActive(profileId, false)
    }

    /** Removes everything stored for a profile, including its app selection. */
    fun removeProfile(profileId: String) = synchronized(LOCK) {
        removeActivation(profileId)
        values.putString(SELECTION_PREFIX + profileId, null)
    }

    /** Every profile id that has anything stored. */
    fun knownProfileIds(): List<String> = synchronized(LOCK) {
        val ids = activeProfileIds.toMutableSet()
        for (key in values.keys()) {
            for (prefix in PROFILE_PREFIXES) {
                if (key.startsWith(prefix)) ids.add(key.removePrefix(prefix))
            }
        }
        ids.sorted()
    }

    /** Removes every value Unspend has stored on the native side. */
    fun removeEverything() = synchronized(LOCK) {
        knownProfileIds().forEach(::removeProfile)
        for (key in listOf(ACTIVE_PROFILE_IDS, SHIELD_STRINGS, ACCESS_REQUESTED, EVENT_LOG)) {
            values.putString(key, null)
        }
    }

    // --- Diagnostics ------------------------------------------------------

    /**
     * Most recent events, oldest first. What the service does is otherwise
     * invisible, so both sides leave a short trail here.
     */
    val eventLog: List<String>
        get() = synchronized(LOCK) { strings(values.getString(EVENT_LOG)) }

    fun log(message: String, now: LocalDateTime) = synchronized(LOCK) {
        val stamp = String.format(
            Locale.ROOT, "%02d-%02d %02d:%02d:%02d",
            now.monthValue, now.dayOfMonth, now.hour, now.minute, now.second,
        )
        val entries = (eventLog + "$stamp $message").takeLast(MAX_LOG_ENTRIES)
        values.putString(EVENT_LOG, JSONArray(entries).toString())
    }

    private fun strings(json: String?): List<String> {
        if (json == null) return emptyList()
        return try {
            val array = JSONArray(json)
            (0 until array.length()).map(array::getString)
        } catch (_: JSONException) {
            emptyList()
        }
    }

    companion object {
        const val MAX_LOG_ENTRIES = 30

        private val LOCK = Any()

        private const val SELECTION_PREFIX = "blockedApps_"
        private const val RULES_PREFIX = "rules_"
        private const val USAGE_PREFIX = "usage_"
        private val PROFILE_PREFIXES = listOf(SELECTION_PREFIX, RULES_PREFIX, USAGE_PREFIX)

        private const val ACTIVE_PROFILE_IDS = "activeProfileIds"
        private const val SHIELD_STRINGS = "shieldStrings"
        private const val ACCESS_REQUESTED = "accessRequested"
        private const val EVENT_LOG = "eventLog"

        private const val USAGE_DAY = "day"
        private const val USAGE_SECONDS = "seconds"
        private const val TRUE = "true"
    }
}
