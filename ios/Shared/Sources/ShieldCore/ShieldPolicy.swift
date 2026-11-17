import Foundation

/// The blocking rule, as a pure function.
///
/// A profile's apps are shielded while ANY of its enabled rules says "block".
/// The display-side mirror lives in
/// `lib/features/app_blocker/domain/shield_policy.dart`; keep them in sync.
enum ShieldPolicy {
    static let minutesPerDay = 24 * 60

    /// DeviceActivity rejects monitoring intervals shorter than this.
    static let minimumScheduleMinutes = 15

    /// DeviceActivity callbacks may arrive a little before the boundary they
    /// announce, and each boundary is announced only once. The rule is
    /// therefore evaluated slightly ahead of the clock: a "window started"
    /// callback sees the window as open, a "window ended" callback sees it
    /// as closed, and the midnight callback already sees the new day. The
    /// cost is acting up to a minute early.
    static let evaluationLeadSeconds: TimeInterval = 60

    /// Slack allowed when judging whether a usage threshold can be real.
    static let thresholdSlackSeconds: TimeInterval = 30

    /// Whether `minuteOfDay` falls inside the half-open window
    /// `[start, end)`. Windows may cross midnight; an empty window
    /// (start == end) contains nothing.
    static func isInsideWindow(minuteOfDay: Int, start: Int, end: Int) -> Bool {
        if start == end { return false }
        if start < end { return minuteOfDay >= start && minuteOfDay < end }
        return minuteOfDay >= start || minuteOfDay < end
    }

    /// Length of the window in minutes, counting across midnight if needed.
    static func windowLength(start: Int, end: Int) -> Int {
        ((end - start) % minutesPerDay + minutesPerDay) % minutesPerDay
    }

    static func isValidSchedule(start: Int, end: Int) -> Bool {
        windowLength(start: start, end: end) >= minimumScheduleMinutes
    }

    /// Should this profile's apps be shielded at `now`?
    ///
    /// - Parameter limitReachedDay: day (`yyyy-MM-dd`) on which the usage
    ///   limit was last reached, as recorded by the monitor extension.
    static func shouldShield(
        rules: ProfileRules,
        limitReachedDay: String?,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        if rules.isManualOnly { return true }
        let ahead = now.addingTimeInterval(evaluationLeadSeconds)

        if let start = rules.scheduleStartMinute, let end = rules.scheduleEndMinute {
            let minute = DayKey.minuteOfDay(for: ahead, calendar: calendar)
            if isInsideWindow(minuteOfDay: minute, start: start, end: end) {
                return true
            }
        }

        let today = DayKey.string(for: ahead, calendar: calendar)
        if rules.taskModeEnabled && rules.tasksDoneDay != today { return true }
        if rules.hasUsageLimit && limitReachedDay == today { return true }
        return false
    }

    /// Whether a "usage limit reached" event arriving at `now` can be real.
    ///
    /// Usage is counted from the later of local midnight and the moment the
    /// monitor was registered, so the budget cannot be used up before that
    /// moment plus the budget itself. Events arriving earlier are spurious
    /// (a known DeviceActivity quirk) and must not block the user.
    ///
    /// - Parameter countsUsageBeforeMonitoring: true on iOS versions where
    ///   usage from earlier in the day counts towards the threshold.
    static func isPlausibleThreshold(
        rules: ProfileRules,
        now: Date,
        calendar: Calendar = .current,
        countsUsageBeforeMonitoring: Bool
    ) -> Bool {
        guard let limit = rules.usageLimitMinutes else { return false }
        let startOfDay = calendar.startOfDay(for: now)
        var countingFrom = startOfDay
        if !countsUsageBeforeMonitoring,
           let registered = rules.limitMonitorStartedAt,
           registered > startOfDay {
            countingFrom = registered
        }
        let needed = TimeInterval(limit * 60) - thresholdSlackSeconds
        return now.timeIntervalSince(countingFrom) >= needed
    }
}
