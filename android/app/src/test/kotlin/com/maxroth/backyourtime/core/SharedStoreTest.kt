package com.maxroth.backyourtime.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

class SharedStoreTest {
    private val values = MemoryKeyValueStore()
    private val store = SharedStore(values)
    private val now = LocalDateTime.of(2026, 11, 17, 12, 0, 5)
    private val today = "2026-11-17"

    private val rules = ProfileRules(
        name = "Social",
        scheduleStartMinute = 540,
        scheduleEndMinute = 1020,
        usageLimitMinutes = 45,
        taskModeEnabled = true,
        tasksDoneDay = today,
    )

    @Test
    fun `rules survive a round trip`() {
        store.saveRules("p1", rules)
        assertEquals(rules, store.rules("p1"))

        val manual = ProfileRules(name = "x")
        store.saveRules("p2", manual)
        assertEquals(manual, store.rules("p2"))
        assertTrue(store.rules("p2")!!.isManualOnly)
    }

    @Test
    fun `unreadable rules read as missing`() {
        values.putString("rules_p1", "not json")
        assertNull(store.rules("p1"))
        assertNull(store.rules("unknown"))
    }

    @Test
    fun `a selection is a set of package names`() {
        assertTrue(store.selection("p1").isEmpty())
        store.setSelection("p1", setOf("com.b", "com.a"))
        assertEquals(setOf("com.a", "com.b"), store.selection("p1"))
    }

    @Test
    fun `active profiles keep their order and appear once`() {
        store.setActive("p1", true)
        store.setActive("p2", true)
        store.setActive("p1", true)
        assertEquals(listOf("p2", "p1"), store.activeProfileIds)

        store.setActive("p2", false)
        assertEquals(listOf("p1"), store.activeProfileIds)
    }

    @Test
    fun `only profiles with rules and apps can be enforced`() {
        for (id in listOf("ok", "noRules", "noApps")) store.setActive(id, true)
        store.saveRules("ok", rules)
        store.setSelection("ok", setOf("com.a"))
        store.setSelection("noRules", setOf("com.a"))
        store.saveRules("noApps", rules)
        store.addUsage("ok", today, 90)

        val profiles = store.activeProfiles(now)

        assertEquals(listOf("ok"), profiles.map { it.id })
        assertEquals(90L, profiles.single().usedSecondsToday)
        assertEquals(setOf("com.a"), profiles.single().packages)
    }

    @Test
    fun `usage adds up within a day and starts again the next`() {
        assertEquals(60L, store.addUsage("p1", today, 60))
        assertEquals(90L, store.addUsage("p1", today, 30))
        assertEquals(90L, store.usedSeconds("p1", today))

        assertEquals(0L, store.usedSeconds("p1", "2026-11-18"))
        assertEquals(10L, store.addUsage("p1", "2026-11-18", 10))
        assertEquals(0L, store.usedSeconds("p1", today))
    }

    @Test
    fun `negative time is not subtracted`() {
        store.addUsage("p1", today, 60)
        assertEquals(60L, store.addUsage("p1", today, -500))
    }

    @Test
    fun `deactivating keeps the selection, deleting does not`() {
        store.setSelection("p1", setOf("com.a"))
        store.saveRules("p1", rules)
        store.addUsage("p1", today, 60)
        store.setActive("p1", true)

        store.removeActivation("p1")

        assertNull(store.rules("p1"))
        assertEquals(0L, store.usedSeconds("p1", today))
        assertTrue(store.activeProfileIds.isEmpty())
        assertEquals(setOf("com.a"), store.selection("p1"))

        store.removeProfile("p1")
        assertTrue(store.selection("p1").isEmpty())
        assertTrue(store.knownProfileIds().isEmpty())
    }

    @Test
    fun `removing everything leaves nothing behind`() {
        store.setSelection("p1", setOf("com.a"))
        store.saveRules("p2", rules)
        store.addUsage("p3", today, 5)
        store.setActive("p4", true)
        store.shieldStrings = ShieldStrings.english.copy(button = "Zurück")
        store.accessRequested = true
        store.log("something", now)
        assertEquals(listOf("p1", "p2", "p3", "p4"), store.knownProfileIds())

        store.removeEverything()

        assertTrue(values.keys().isEmpty())
        assertEquals(ShieldStrings.english, store.shieldStrings)
        assertFalse(store.accessRequested)
    }

    @Test
    fun `the block screen text survives a round trip`() {
        val german = ShieldStrings(
            titleTemplate = "{app} ist gesperrt",
            subtitleTemplate = "Gesperrt von „{profile}“",
            subtitleGeneric = "Gesperrt von Unspend",
            button = "Zurück",
            appFallback = "Diese App",
            websiteFallback = "Diese Website",
        )
        store.shieldStrings = german
        assertEquals(german, store.shieldStrings)
        assertEquals("Uhr ist gesperrt", german.title("Uhr"))
        assertEquals("Diese App ist gesperrt", german.title(null))
        assertEquals("Gesperrt von „Arbeit“", german.subtitle("Arbeit"))
        assertEquals("Gesperrt von Unspend", german.subtitle(""))
    }

    @Test
    fun `incomplete block screen text is refused`() {
        assertNull(ShieldStrings.fromMap(mapOf(ShieldStrings.TITLE to "x")))
        assertNull(ShieldStrings.fromJson("{}"))
    }

    @Test
    fun `the event log keeps the newest entries`() {
        repeat(SharedStore.MAX_LOG_ENTRIES + 5) { store.log("event $it", now) }

        val log = store.eventLog
        assertEquals(SharedStore.MAX_LOG_ENTRIES, log.size)
        assertEquals("11-17 12:00:05 event 5", log.first())
        assertEquals("11-17 12:00:05 event 34", log.last())
    }
}
