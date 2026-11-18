package com.maxroth.backyourtime.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

class BlockerTest {
    private val noon = LocalDateTime.of(2026, 11, 17, 12, 0)
    private val evening = LocalDateTime.of(2026, 11, 17, 20, 0)

    private val manual = ActiveProfile("manual", ProfileRules(name = "Social"), setOf("a", "b"), 0)
    private val workHours = ActiveProfile(
        "work",
        ProfileRules(name = "Work", scheduleStartMinute = 540, scheduleEndMinute = 1020),
        setOf("b", "c"),
        0,
    )
    private val limited = ActiveProfile(
        "video",
        ProfileRules(name = "Video", usageLimitMinutes = 45),
        setOf("v"),
        usedSecondsToday = 600,
    )

    @Test
    fun `an app no profile covers is not blocked`() {
        assertNull(Blocker.blockingProfile("z", listOf(manual, workHours), noon))
        assertFalse(Blocker.isWatched("z", listOf(manual, workHours)))
    }

    @Test
    fun `the first profile that blocks the app is named`() {
        assertEquals("manual", Blocker.blockingProfile("b", listOf(manual, workHours), noon)?.id)
        assertEquals("work", Blocker.blockingProfile("b", listOf(workHours, manual), noon)?.id)
    }

    @Test
    fun `a profile that covers the app but does not block now is skipped`() {
        assertEquals("manual", Blocker.blockingProfile("b", listOf(workHours, manual), evening)?.id)
        assertNull(Blocker.blockingProfile("c", listOf(workHours), evening))
        assertTrue(Blocker.isWatched("c", listOf(workHours)))
    }

    @Test
    fun `a limited app counts against its budget while it is open`() {
        assertEquals(listOf(limited), Blocker.meteredProfiles("v", listOf(manual, limited), noon))
        assertNull(Blocker.blockingProfile("v", listOf(limited), noon))
    }

    @Test
    fun `a used-up budget blocks and stops counting`() {
        val used = limited.copy(usedSecondsToday = 45 * 60)
        assertEquals("video", Blocker.blockingProfile("v", listOf(used), noon)?.id)
        assertTrue(Blocker.meteredProfiles("v", listOf(used), noon).isEmpty())
    }

    @Test
    fun `time does not count while another rule of the profile blocks`() {
        val both = ActiveProfile(
            "both",
            ProfileRules(
                name = "Both",
                scheduleStartMinute = 540,
                scheduleEndMinute = 1020,
                usageLimitMinutes = 45,
            ),
            setOf("v"),
            0,
        )
        assertTrue(Blocker.meteredProfiles("v", listOf(both), noon).isEmpty())
        assertEquals(listOf(both), Blocker.meteredProfiles("v", listOf(both), evening))
    }
}
