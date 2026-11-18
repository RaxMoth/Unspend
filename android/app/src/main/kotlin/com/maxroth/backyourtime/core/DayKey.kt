package com.maxroth.backyourtime.core

import java.time.LocalDateTime
import java.util.Locale

/** Calendar helpers shared by the bridge and the blocker service. */
object DayKey {
    /**
     * Local calendar day of [time] as `yyyy-MM-dd`.
     *
     * Facts such as "today's tasks are done" are stamped with the day they
     * happened on, so they stop applying by themselves at midnight. The Dart
     * side (`lib/core/time/day_key.dart`) and iOS use the same format.
     */
    fun string(time: LocalDateTime): String =
        String.format(Locale.ROOT, "%04d-%02d-%02d", time.year, time.monthValue, time.dayOfMonth)

    /** Minutes since local midnight (0..1439). */
    fun minuteOfDay(time: LocalDateTime): Int = time.hour * 60 + time.minute
}
