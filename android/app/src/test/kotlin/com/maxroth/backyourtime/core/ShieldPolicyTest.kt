package com.maxroth.backyourtime.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

class ShieldPolicyTest {
    private fun at(hour: Int, minute: Int = 0, day: Int = 17): LocalDateTime =
        LocalDateTime.of(2026, 11, day, hour, minute)

    private val today = "2026-11-17"

    // --- Windows ------------------------------------------------------------

    @Test
    fun `a daytime window is half-open`() {
        assertFalse(ShieldPolicy.isInsideWindow(539, 540, 1020))
        assertTrue(ShieldPolicy.isInsideWindow(540, 540, 1020))
        assertTrue(ShieldPolicy.isInsideWindow(1019, 540, 1020))
        assertFalse(ShieldPolicy.isInsideWindow(1020, 540, 1020))
    }

    @Test
    fun `an overnight window wraps past midnight`() {
        val start = 22 * 60
        val end = 6 * 60
        assertTrue(ShieldPolicy.isInsideWindow(23 * 60, start, end))
        assertTrue(ShieldPolicy.isInsideWindow(0, start, end))
        assertTrue(ShieldPolicy.isInsideWindow(5 * 60 + 59, start, end))
        assertFalse(ShieldPolicy.isInsideWindow(6 * 60, start, end))
        assertFalse(ShieldPolicy.isInsideWindow(12 * 60, start, end))
    }

    @Test
    fun `an empty window contains nothing`() {
        assertFalse(ShieldPolicy.isInsideWindow(600, 600, 600))
    }

    @Test
    fun `window length counts across midnight`() {
        assertEquals(480, ShieldPolicy.windowLength(540, 1020))
        assertEquals(480, ShieldPolicy.windowLength(22 * 60, 6 * 60))
        assertEquals(0, ShieldPolicy.windowLength(600, 600))
    }

    @Test
    fun `a schedule needs fifteen minutes`() {
        assertFalse(ShieldPolicy.isValidSchedule(600, 614))
        assertTrue(ShieldPolicy.isValidSchedule(600, 615))
        assertTrue(ShieldPolicy.isValidSchedule(23 * 60 + 50, 5))
        assertFalse(ShieldPolicy.isValidSchedule(600, 600))
    }

    // --- The rule -----------------------------------------------------------

    @Test
    fun `a profile without rules blocks all the time`() {
        assertTrue(ShieldPolicy.shouldShield(ProfileRules(name = "x"), 0, at(3)))
    }

    @Test
    fun `a schedule blocks inside its window only`() {
        val rules = ProfileRules(name = "x", scheduleStartMinute = 540, scheduleEndMinute = 1020)
        assertFalse(ShieldPolicy.shouldShield(rules, 0, at(8, 59)))
        assertTrue(ShieldPolicy.shouldShield(rules, 0, at(9)))
        assertTrue(ShieldPolicy.shouldShield(rules, 0, at(16, 59)))
        assertFalse(ShieldPolicy.shouldShield(rules, 0, at(17)))
    }

    @Test
    fun `task mode blocks until today's tasks are done`() {
        val pending = ProfileRules(name = "x", taskModeEnabled = true)
        assertTrue(ShieldPolicy.shouldShield(pending, 0, at(12)))

        val done = pending.copy(tasksDoneDay = today)
        assertFalse(ShieldPolicy.shouldShield(done, 0, at(12)))
    }

    @Test
    fun `tasks done yesterday are pending again after midnight`() {
        val rules = ProfileRules(name = "x", taskModeEnabled = true, tasksDoneDay = today)
        assertFalse(ShieldPolicy.shouldShield(rules, 0, at(23, 59)))
        assertTrue(ShieldPolicy.shouldShield(rules, 0, at(0, 0, day = 18)))
    }

    @Test
    fun `a usage limit blocks once the budget is used up`() {
        val rules = ProfileRules(name = "x", usageLimitMinutes = 45)
        assertFalse(ShieldPolicy.shouldShield(rules, 0, at(12)))
        assertFalse(ShieldPolicy.shouldShield(rules, 45 * 60 - 1, at(12)))
        assertTrue(ShieldPolicy.shouldShield(rules, 45 * 60, at(12)))
        assertTrue(ShieldPolicy.isLimitReached(rules, 45 * 60))
    }

    @Test
    fun `no limit is never reached`() {
        assertFalse(ShieldPolicy.isLimitReached(ProfileRules(name = "x"), Long.MAX_VALUE))
    }

    @Test
    fun `any rule that says block is enough`() {
        val rules = ProfileRules(
            name = "x",
            scheduleStartMinute = 540,
            scheduleEndMinute = 1020,
            usageLimitMinutes = 30,
            taskModeEnabled = true,
            tasksDoneDay = today,
        )
        // Outside the window, tasks done, budget left.
        assertFalse(ShieldPolicy.shouldShield(rules, 0, at(20)))
        // Each rule on its own.
        assertTrue(ShieldPolicy.shouldShield(rules, 0, at(10)))
        assertTrue(ShieldPolicy.shouldShield(rules, 30 * 60, at(20)))
        assertTrue(ShieldPolicy.shouldShield(rules.copy(tasksDoneDay = null), 0, at(20)))
    }

    // --- Day key ------------------------------------------------------------

    @Test
    fun `the day key is zero-padded`() {
        assertEquals("2026-01-05", DayKey.string(LocalDateTime.of(2026, 1, 5, 0, 0)))
        assertEquals(0, DayKey.minuteOfDay(LocalDateTime.of(2026, 1, 5, 0, 0)))
        assertEquals(1439, DayKey.minuteOfDay(LocalDateTime.of(2026, 1, 5, 23, 59)))
    }
}
