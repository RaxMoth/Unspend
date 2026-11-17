import XCTest
@testable import ShieldCore

final class ShieldPolicyTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    /// A moment on 17 November 2026 (or another `day` of that month).
    private func date(_ hour: Int, _ minute: Int = 0, _ second: Int = 0, day: Int = 17) -> Date {
        calendar.date(from: DateComponents(
            year: 2026, month: 11, day: day, hour: hour, minute: minute, second: second
        ))!
    }

    private func minute(_ hour: Int, _ minute: Int = 0) -> Int { hour * 60 + minute }

    private func rules(
        schedule: (start: Int, end: Int)? = nil,
        limit: Int? = nil,
        taskMode: Bool = false,
        tasksDoneDay: String? = nil,
        monitorStartedAt: Date? = nil
    ) -> ProfileRules {
        ProfileRules(
            name: "Focus",
            scheduleStartMinute: schedule?.start,
            scheduleEndMinute: schedule?.end,
            usageLimitMinutes: limit,
            taskModeEnabled: taskMode,
            tasksDoneDay: tasksDoneDay,
            limitMonitorStartedAt: monitorStartedAt
        )
    }

    private func shield(_ rules: ProfileRules, limitReachedDay: String? = nil, at now: Date) -> Bool {
        ShieldPolicy.shouldShield(
            rules: rules, limitReachedDay: limitReachedDay, now: now, calendar: calendar
        )
    }

    // MARK: Window math

    func testSameDayWindowIsHalfOpen() {
        let inside = { ShieldPolicy.isInsideWindow(minuteOfDay: $0, start: self.minute(9), end: self.minute(17)) }
        XCTAssertFalse(inside(minute(8, 59)))
        XCTAssertTrue(inside(minute(9)))
        XCTAssertTrue(inside(minute(16, 59)))
        XCTAssertFalse(inside(minute(17)))
    }

    func testOvernightWindowWrapsPastMidnight() {
        let inside = { ShieldPolicy.isInsideWindow(minuteOfDay: $0, start: self.minute(22), end: self.minute(6)) }
        XCTAssertFalse(inside(minute(21, 59)))
        XCTAssertTrue(inside(minute(22)))
        XCTAssertTrue(inside(minute(23, 59)))
        XCTAssertTrue(inside(0))
        XCTAssertTrue(inside(minute(5, 59)))
        XCTAssertFalse(inside(minute(6)))
        XCTAssertFalse(inside(minute(12)))
    }

    func testEmptyWindowContainsNothing() {
        XCTAssertFalse(ShieldPolicy.isInsideWindow(minuteOfDay: minute(9), start: minute(9), end: minute(9)))
    }

    func testScheduleValidation() {
        XCTAssertEqual(ShieldPolicy.windowLength(start: minute(22), end: minute(6)), 8 * 60)
        XCTAssertEqual(ShieldPolicy.windowLength(start: minute(9), end: minute(9)), 0)
        XCTAssertFalse(ShieldPolicy.isValidSchedule(start: minute(9), end: minute(9)))
        XCTAssertFalse(ShieldPolicy.isValidSchedule(start: minute(9), end: minute(9, 14)))
        XCTAssertTrue(ShieldPolicy.isValidSchedule(start: minute(9), end: minute(9, 15)))
        XCTAssertFalse(ShieldPolicy.isValidSchedule(start: minute(23, 50), end: minute(0, 4)))
        XCTAssertTrue(ShieldPolicy.isValidSchedule(start: minute(23, 50), end: minute(0, 5)))
    }

    // MARK: Single rules

    func testManualProfileIsAlwaysShielded() {
        XCTAssertTrue(shield(rules(), at: date(3)))
        XCTAssertTrue(shield(rules(), at: date(15)))
    }

    func testScheduleShieldsOnlyInsideTheWindow() {
        let r = rules(schedule: (minute(9), minute(17)))
        XCTAssertFalse(shield(r, at: date(8)))
        XCTAssertTrue(shield(r, at: date(12)))
        XCTAssertFalse(shield(r, at: date(18)))
    }

    func testUsageLimitDoesNotShieldUntilReached() {
        let r = rules(limit: 30)
        XCTAssertFalse(shield(r, at: date(12)), "an armed limit must not block by itself")
        XCTAssertTrue(shield(r, limitReachedDay: "2026-11-17", at: date(12)))
    }

    func testReachedLimitExpiresAtMidnight() {
        let r = rules(limit: 30)
        XCTAssertTrue(shield(r, limitReachedDay: "2026-11-17", at: date(23, 58, 30)))
        XCTAssertFalse(shield(r, limitReachedDay: "2026-11-17", at: date(0, day: 18)))
    }

    func testMidnightCallbackArrivingEarlyAlreadySeesTheNewDay() {
        // The midnight callback is delivered once; if it comes two seconds
        // early it must still lift yesterday's limit and re-lock the tasks.
        let early = date(23, 59, 58)
        XCTAssertFalse(shield(rules(limit: 30), limitReachedDay: "2026-11-17", at: early))
        XCTAssertTrue(shield(rules(taskMode: true, tasksDoneDay: "2026-11-17"), at: early))
    }

    func testTaskModeShieldsUntilTasksAreDoneToday() {
        XCTAssertTrue(shield(rules(taskMode: true), at: date(12)))
        XCTAssertFalse(shield(rules(taskMode: true, tasksDoneDay: "2026-11-17"), at: date(12)))
    }

    func testTasksCountAsPendingAgainAfterMidnight() {
        let r = rules(taskMode: true, tasksDoneDay: "2026-11-17")
        XCTAssertFalse(shield(r, at: date(23, 58, 30)))
        XCTAssertTrue(shield(r, at: date(0, day: 18)), "daily reset must re-lock without the app running")
    }

    // MARK: Stacked rules

    func testDoneTasksDoNotUnblockInsideTheSchedule() {
        let r = rules(schedule: (minute(9), minute(17)), taskMode: true, tasksDoneDay: "2026-11-17")
        XCTAssertTrue(shield(r, at: date(12)))
        XCTAssertFalse(shield(r, at: date(18)))
    }

    func testPendingTasksKeepBlockingAfterTheScheduleEnds() {
        let r = rules(schedule: (minute(9), minute(17)), taskMode: true)
        XCTAssertTrue(shield(r, at: date(18)))
    }

    func testReachedLimitKeepsBlockingAfterTheScheduleEnds() {
        let r = rules(schedule: (minute(9), minute(17)), limit: 30)
        XCTAssertFalse(shield(r, at: date(18)))
        XCTAssertTrue(shield(r, limitReachedDay: "2026-11-17", at: date(18)))
    }

    func testOvernightScheduleSurvivesTheLimitDayRollover() {
        // Limit day ends at 23:59, schedule runs 22:00–06:00: must stay shielded.
        let r = rules(schedule: (minute(22), minute(6)), limit: 30)
        XCTAssertTrue(shield(r, at: date(23, 59)))
        XCTAssertTrue(shield(r, at: date(0, day: 18)))
        XCTAssertFalse(shield(r, at: date(6, day: 18)))
    }

    // MARK: Callback timing

    func testCallbackArrivingJustBeforeTheWindowStartCountsAsInside() {
        let r = rules(schedule: (minute(9), minute(17)))
        XCTAssertTrue(shield(r, at: date(8, 59, 58)))
        XCTAssertFalse(shield(r, at: date(8, 58, 30)), "more than the lead time early is still outside")
    }

    func testCallbackArrivingJustBeforeTheWindowEndCountsAsOutside() {
        let r = rules(schedule: (minute(9), minute(17)))
        XCTAssertFalse(shield(r, at: date(16, 59, 58)))
        XCTAssertTrue(shield(r, at: date(16, 58, 30)))
    }

    func testLateCallbacksAreJudgedByTheClock() {
        let r = rules(schedule: (minute(9), minute(17)))
        XCTAssertTrue(shield(r, at: date(9, 0, 20)))
        XCTAssertFalse(shield(r, at: date(17, 0, 20)))
    }

    // MARK: Spurious threshold events

    func testThresholdRightAfterRegistrationIsImplausible() {
        let r = rules(limit: 30, monitorStartedAt: date(12))
        let plausible = { ShieldPolicy.isPlausibleThreshold(
            rules: r, now: $0, calendar: self.calendar, countsUsageBeforeMonitoring: false
        ) }
        XCTAssertFalse(plausible(date(12, 0, 5)))
        XCTAssertFalse(plausible(date(12, 20)))
        XCTAssertTrue(plausible(date(12, 30)))
        XCTAssertTrue(plausible(date(12, 29, 45)), "within the allowed slack")
    }

    func testThresholdOnALaterDayCountsFromMidnight() {
        let r = rules(limit: 30, monitorStartedAt: date(12, day: 16))
        let plausible = { ShieldPolicy.isPlausibleThreshold(
            rules: r, now: $0, calendar: self.calendar, countsUsageBeforeMonitoring: false
        ) }
        XCTAssertFalse(plausible(date(0, 10)))
        XCTAssertTrue(plausible(date(0, 30)))
    }

    func testOlderSystemsCountUsageFromMidnight() {
        // Monitor registered at noon, but the system counts the morning too.
        let r = rules(limit: 30, monitorStartedAt: date(12))
        XCTAssertTrue(ShieldPolicy.isPlausibleThreshold(
            rules: r, now: date(12, 0, 5), calendar: calendar, countsUsageBeforeMonitoring: true
        ))
    }

    func testThresholdWithoutALimitIsNeverPlausible() {
        XCTAssertFalse(ShieldPolicy.isPlausibleThreshold(
            rules: rules(), now: date(12), calendar: calendar, countsUsageBeforeMonitoring: false
        ))
    }

    // MARK: Day key

    func testDayKeyAndMinuteOfDayUseTheLocalCalendar() {
        XCTAssertEqual(DayKey.string(for: date(0), calendar: calendar), "2026-11-17")
        XCTAssertEqual(DayKey.string(for: date(23, 59, 59), calendar: calendar), "2026-11-17")
        XCTAssertEqual(DayKey.minuteOfDay(for: date(9, 5), calendar: calendar), 545)
    }
}
