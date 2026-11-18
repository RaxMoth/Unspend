package com.maxroth.backyourtime.core

import java.time.LocalDateTime

/**
 * The blocking rule, as pure functions.
 *
 * A profile's apps are blocked while ANY of its enabled rules says "block".
 * The same rule exists in Swift (`ShieldPolicy.swift`) and, for display, in
 * Dart (`lib/features/app_blocker/domain/shield_policy.dart`); keep the three
 * in sync.
 *
 * Unlike iOS, nothing here looks ahead of the clock: Android asks the rule
 * at the moment an app comes to the front, not at announced boundaries.
 */
object ShieldPolicy {
    const val MINUTES_PER_DAY = 24 * 60

    /** Shortest schedule; the same as on iOS so a profile is valid on both. */
    const val MINIMUM_SCHEDULE_MINUTES = 15

    /**
     * Whether [minuteOfDay] falls inside the half-open window `[start, end)`.
     * Windows may cross midnight; an empty window (start == end) contains
     * nothing.
     */
    fun isInsideWindow(minuteOfDay: Int, start: Int, end: Int): Boolean = when {
        start == end -> false
        start < end -> minuteOfDay in start until end
        else -> minuteOfDay >= start || minuteOfDay < end
    }

    /** Length of the window in minutes, counting across midnight if needed. */
    fun windowLength(start: Int, end: Int): Int =
        ((end - start) % MINUTES_PER_DAY + MINUTES_PER_DAY) % MINUTES_PER_DAY

    fun isValidSchedule(start: Int, end: Int): Boolean =
        windowLength(start, end) >= MINIMUM_SCHEDULE_MINUTES

    /** Whether the daily budget of [rules] is used up by [usedSecondsToday]. */
    fun isLimitReached(rules: ProfileRules, usedSecondsToday: Long): Boolean {
        val limit = rules.usageLimitMinutes ?: return false
        return usedSecondsToday >= limit * 60L
    }

    /** Should this profile's apps be blocked at [now]? */
    fun shouldShield(rules: ProfileRules, usedSecondsToday: Long, now: LocalDateTime): Boolean {
        if (rules.isManualOnly) return true

        val start = rules.scheduleStartMinute
        val end = rules.scheduleEndMinute
        if (start != null && end != null &&
            isInsideWindow(DayKey.minuteOfDay(now), start, end)
        ) {
            return true
        }

        if (rules.taskModeEnabled && rules.tasksDoneDay != DayKey.string(now)) return true
        return isLimitReached(rules, usedSecondsToday)
    }
}
