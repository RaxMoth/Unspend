import Foundation

/// Snapshot of one profile's blocking rules.
///
/// The app writes it into the App Group when a profile is activated; the
/// monitor extension reads it to decide whether the profile's apps should be
/// shielded right now. Only the app ever writes it.
struct ProfileRules: Codable, Equatable {
    /// Profile name, shown on the shield screen.
    var name: String

    /// Schedule window as minutes of the day (0...1439). Nil when the
    /// schedule rule is off.
    var scheduleStartMinute: Int?
    var scheduleEndMinute: Int?

    /// Daily usage budget in minutes. Nil when the usage-limit rule is off.
    var usageLimitMinutes: Int?

    /// Whether the apps stay blocked until the day's tasks are done.
    var taskModeEnabled: Bool

    /// Day (`yyyy-MM-dd`) on which every task was completed. Compared with
    /// today, so tasks count as pending again after midnight.
    var tasksDoneDay: String?

    /// When usage counting for the current monitor began. A "limit reached"
    /// event that arrives sooner than this plus the budget cannot be real.
    var limitMonitorStartedAt: Date?

    var hasSchedule: Bool {
        scheduleStartMinute != nil && scheduleEndMinute != nil
    }

    var hasUsageLimit: Bool { usageLimitMinutes != nil }

    /// No automatic rule: blocked from activation until deactivation.
    var isManualOnly: Bool {
        !hasSchedule && !hasUsageLimit && !taskModeEnabled
    }

    /// Rules that depend on the calendar day need a daily monitor so the
    /// extension is woken at midnight.
    var needsDayActivity: Bool { hasUsageLimit || taskModeEnabled }
}
