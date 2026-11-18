package com.maxroth.backyourtime.core

import java.time.LocalDateTime

/** An active profile with everything needed to judge it. */
data class ActiveProfile(
    val id: String,
    val rules: ProfileRules,
    /** Package names of the apps the profile covers. */
    val packages: Set<String>,
    /** Time spent in those apps today while they were not blocked. */
    val usedSecondsToday: Long,
) {
    fun isShielded(now: LocalDateTime): Boolean =
        ShieldPolicy.shouldShield(rules, usedSecondsToday, now)
}

/** Decisions about the app that is in front. */
object Blocker {
    /** The first active profile that blocks [packageName] at [now], if any. */
    fun blockingProfile(
        packageName: String,
        profiles: List<ActiveProfile>,
        now: LocalDateTime,
    ): ActiveProfile? = profiles.firstOrNull { packageName in it.packages && it.isShielded(now) }

    /**
     * Profiles whose daily budget is being used while [packageName] is in
     * front: those with a usage limit that cover the app and do not block
     * it at the moment.
     */
    fun meteredProfiles(
        packageName: String,
        profiles: List<ActiveProfile>,
        now: LocalDateTime,
    ): List<ActiveProfile> = profiles.filter {
        it.rules.hasUsageLimit && packageName in it.packages && !it.isShielded(now)
    }

    /** Whether any active profile covers [packageName], blocked or not. */
    fun isWatched(packageName: String, profiles: List<ActiveProfile>): Boolean =
        profiles.any { packageName in it.packages }
}
