import XCTest
@testable import ShieldCore

final class SharedStoreTests: XCTestCase {
    private var suiteName: String!
    private var store: SharedStore!

    override func setUp() {
        super.setUp()
        suiteName = "ShieldCoreTests-\(UUID().uuidString)"
        store = SharedStore(suiteName: suiteName)
        XCTAssertNotNil(store)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private let rules = ProfileRules(
        name: "Evening",
        scheduleStartMinute: 22 * 60,
        scheduleEndMinute: 6 * 60,
        usageLimitMinutes: 45,
        taskModeEnabled: true,
        tasksDoneDay: "2026-11-17",
        limitMonitorStartedAt: Date(timeIntervalSince1970: 1_800_000_000)
    )

    // MARK: Rules

    func testRulesRoundTrip() {
        store.saveRules(rules, for: "p1")
        XCTAssertEqual(store.rules(for: "p1"), rules)
        XCTAssertNil(store.rules(for: "other"))
    }

    func testRuleFlagsFollowTheEnabledRules() {
        XCTAssertTrue(rules.hasSchedule)
        XCTAssertTrue(rules.hasUsageLimit)
        XCTAssertTrue(rules.needsDayActivity)
        XCTAssertFalse(rules.isManualOnly)

        let manual = ProfileRules(name: "Manual", taskModeEnabled: false)
        XCTAssertTrue(manual.isManualOnly)
        XCTAssertFalse(manual.needsDayActivity)

        let scheduleOnly = ProfileRules(
            name: "Work", scheduleStartMinute: 540, scheduleEndMinute: 1020, taskModeEnabled: false
        )
        XCTAssertFalse(scheduleOnly.needsDayActivity)
    }

    // MARK: Active profiles and facts

    func testActiveProfilesAreTrackedWithoutDuplicates() {
        store.setActive(true, profileId: "a")
        store.setActive(true, profileId: "b")
        store.setActive(true, profileId: "a")
        XCTAssertEqual(store.activeProfileIds.sorted(), ["a", "b"])

        store.setActive(false, profileId: "a")
        XCTAssertEqual(store.activeProfileIds, ["b"])
    }

    func testLimitReachedDayCanBeSetAndCleared() {
        store.setLimitReachedDay("2026-11-17", for: "p1")
        XCTAssertEqual(store.limitReachedDay(for: "p1"), "2026-11-17")
        store.setLimitReachedDay(nil, for: "p1")
        XCTAssertNil(store.limitReachedDay(for: "p1"))
    }

    // MARK: Removal

    func testRemovingAnActivationKeepsTheSelection() {
        store.setSelectionData(Data([1, 2, 3]), for: "p1")
        store.saveRules(rules, for: "p1")
        store.setLimitReachedDay("2026-11-17", for: "p1")
        store.setActive(true, profileId: "p1")

        store.removeActivation(for: "p1")

        XCTAssertNil(store.rules(for: "p1"))
        XCTAssertNil(store.limitReachedDay(for: "p1"))
        XCTAssertTrue(store.activeProfileIds.isEmpty)
        XCTAssertEqual(store.selectionData(for: "p1"), Data([1, 2, 3]))
    }

    func testRemovingAProfileAlsoRemovesItsSelection() {
        store.setSelectionData(Data([1]), for: "p1")
        store.setSelectionData(Data([2]), for: "p2")

        store.removeProfile("p1")

        XCTAssertNil(store.selectionData(for: "p1"))
        XCTAssertEqual(store.selectionData(for: "p2"), Data([2]))
    }

    func testKnownProfileIdsCoversEveryKindOfStoredValue() {
        store.setSelectionData(Data([1]), for: "picked")
        store.saveRules(rules, for: "ruled")
        store.setLimitReachedDay("2026-11-17", for: "limited")
        store.setActive(true, profileId: "active")

        XCTAssertEqual(store.knownProfileIds(), ["active", "limited", "picked", "ruled"])
    }

    func testRemoveEverythingLeavesNothingBehind() {
        store.setSelectionData(Data([1]), for: "p1")
        store.saveRules(rules, for: "p1")
        store.setActive(true, profileId: "p1")
        store.saveShieldStrings(.english)
        store.log("something happened")
        store.defaults.set("legacy", forKey: "activeProfileName")
        store.defaults.set(Data([9]), forKey: "blockedApps")

        store.removeEverything()

        XCTAssertTrue(store.knownProfileIds().isEmpty)
        XCTAssertTrue(store.eventLog.isEmpty)
        XCTAssertNil(store.defaults.object(forKey: "activeProfileName"))
        XCTAssertNil(store.defaults.object(forKey: "blockedApps"))
        XCTAssertNil(store.defaults.object(forKey: "shieldStrings"))
    }

    // MARK: Uninstall protection

    func testAppRemovalIsLockedOnlyWhileAProfileIsActive() {
        XCTAssertTrue(store.removalLockEnabled, "on unless switched off")
        XCTAssertFalse(store.shouldLockAppRemoval, "nothing is active")

        store.setActive(true, profileId: "a")
        XCTAssertTrue(store.shouldLockAppRemoval)

        store.setActive(false, profileId: "a")
        XCTAssertFalse(store.shouldLockAppRemoval)
    }

    func testUninstallProtectionCanBeSwitchedOff() {
        store.setActive(true, profileId: "a")

        store.setRemovalLockEnabled(false)
        XCTAssertFalse(store.shouldLockAppRemoval)

        store.setRemovalLockEnabled(true)
        XCTAssertTrue(store.shouldLockAppRemoval)
    }

    func testRemoveEverythingRestoresTheDefaultUninstallProtection() {
        store.setRemovalLockEnabled(false)

        store.removeEverything()

        XCTAssertTrue(store.removalLockEnabled)
    }

    // MARK: Shield text

    func testShieldStringsDefaultToEnglish() {
        XCTAssertEqual(store.shieldStrings, .english)
    }

    func testShieldStringsRoundTripAndFillPlaceholders() {
        let german = ShieldStrings(
            titleTemplate: "{app} ist blockiert",
            subtitleTemplate: "Blockiert durch „{profile}“ in Unspend",
            subtitleGeneric: "Blockiert durch Unspend",
            button: "Zurück",
            appFallback: "Diese App",
            websiteFallback: "Diese Website"
        )
        store.saveShieldStrings(german)
        let loaded = store.shieldStrings

        XCTAssertEqual(loaded, german)
        XCTAssertEqual(loaded.title(for: "Instagram", isWebsite: false), "Instagram ist blockiert")
        XCTAssertEqual(loaded.title(for: nil, isWebsite: false), "Diese App ist blockiert")
        XCTAssertEqual(loaded.title(for: "", isWebsite: true), "Diese Website ist blockiert")
        XCTAssertEqual(loaded.subtitle(profileName: "Arbeit"), "Blockiert durch „Arbeit“ in Unspend")
        XCTAssertEqual(loaded.subtitle(profileName: nil), "Blockiert durch Unspend")
    }

    // MARK: Diagnostics

    func testEventLogKeepsOnlyTheMostRecentEntries() {
        for index in 0..<(SharedStore.maxLogEntries + 5) {
            store.log("event \(index)")
        }
        let log = store.eventLog
        XCTAssertEqual(log.count, SharedStore.maxLogEntries)
        XCTAssertTrue(log.first!.hasSuffix("event 5"))
        XCTAssertTrue(log.last!.hasSuffix("event \(SharedStore.maxLogEntries + 4)"))
    }
}
