package com.maxroth.backyourtime.core

import org.json.JSONException
import org.json.JSONObject

/**
 * Snapshot of one profile's blocking rules.
 *
 * The app writes it when a profile is activated; the blocker service reads
 * it to decide whether the profile's apps are blocked right now. Mirrors
 * `ProfileRules.swift`.
 */
data class ProfileRules(
    /** Profile name, shown on the block screen. */
    val name: String,
    /** Schedule window as minutes of the day (0..1439); both or neither. */
    val scheduleStartMinute: Int? = null,
    val scheduleEndMinute: Int? = null,
    /** Daily usage budget in minutes. Null when the usage-limit rule is off. */
    val usageLimitMinutes: Int? = null,
    /** Whether the apps stay blocked until the day's tasks are done. */
    val taskModeEnabled: Boolean = false,
    /**
     * Day (`yyyy-MM-dd`) on which every task was completed. Compared with
     * today, so tasks count as pending again after midnight.
     */
    val tasksDoneDay: String? = null,
) {
    val hasSchedule: Boolean
        get() = scheduleStartMinute != null && scheduleEndMinute != null

    val hasUsageLimit: Boolean
        get() = usageLimitMinutes != null

    /** No automatic rule: blocked from activation until deactivation. */
    val isManualOnly: Boolean
        get() = !hasSchedule && !hasUsageLimit && !taskModeEnabled

    fun toJson(): String = JSONObject().apply {
        put(NAME, name)
        scheduleStartMinute?.let { put(SCHEDULE_START, it) }
        scheduleEndMinute?.let { put(SCHEDULE_END, it) }
        usageLimitMinutes?.let { put(USAGE_LIMIT, it) }
        put(TASK_MODE, taskModeEnabled)
        tasksDoneDay?.let { put(TASKS_DONE_DAY, it) }
    }.toString()

    companion object {
        private const val NAME = "name"
        private const val SCHEDULE_START = "scheduleStartMinute"
        private const val SCHEDULE_END = "scheduleEndMinute"
        private const val USAGE_LIMIT = "usageLimitMinutes"
        private const val TASK_MODE = "taskModeEnabled"
        private const val TASKS_DONE_DAY = "tasksDoneDay"

        /** Null when [json] is not a rules snapshot. */
        fun fromJson(json: String): ProfileRules? = try {
            val o = JSONObject(json)
            ProfileRules(
                name = o.optString(NAME),
                scheduleStartMinute = o.intOrNull(SCHEDULE_START),
                scheduleEndMinute = o.intOrNull(SCHEDULE_END),
                usageLimitMinutes = o.intOrNull(USAGE_LIMIT),
                taskModeEnabled = o.optBoolean(TASK_MODE),
                tasksDoneDay = if (o.has(TASKS_DONE_DAY)) o.getString(TASKS_DONE_DAY) else null,
            )
        } catch (_: JSONException) {
            null
        }

        private fun JSONObject.intOrNull(key: String): Int? = if (has(key)) getInt(key) else null
    }
}
