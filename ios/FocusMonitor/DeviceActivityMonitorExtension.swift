import DeviceActivity
import Foundation

/// Woken by iOS when one of Unspend's monitors reaches a boundary, even while
/// the app is not running:
///   • `unspend.schedule.<id>` starts / ends — the schedule window opened or closed
///   • `unspend.day.<id>` starts / ends      — midnight: daily limit and tasks reset
///   • the usage threshold on the day monitor — today's budget is used up
///
/// The extension never decides by the kind of callback alone. It records the
/// one fact only it can know (the limit was reached today) and then asks
/// `ShieldEnforcer` to re-evaluate the profile's rules, so stacked rules
/// cannot cancel each other.
class FocusMonitor: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        evaluate(activity, reason: "start")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        evaluate(activity, reason: "end")
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        guard event.rawValue == ActivityNames.limitReachedEvent,
              let parsed = ActivityNames.parse(activity.rawValue),
              parsed.kind == .day,
              let shared = SharedStore(),
              let rules = shared.rules(for: parsed.profileId) else { return }

        let now = Date()
        guard ShieldPolicy.isPlausibleThreshold(
            rules: rules,
            now: now,
            countsUsageBeforeMonitoring: Self.countsUsageBeforeMonitoring
        ) else {
            shared.log("limit \(parsed.profileId.suffix(6)): ignored, too early to be real", now: now)
            return
        }

        shared.setLimitReachedDay(DayKey.string(for: now), for: parsed.profileId)
        ShieldEnforcer.evaluate(
            profileId: parsed.profileId, shared: shared, now: now, reason: "limit"
        )
    }

    // MARK: - Helpers

    /// Before iOS 17.4 usage from earlier in the day counts towards a
    /// threshold; from 17.4 on the app asks for counting to start when the
    /// monitor is registered.
    private static var countsUsageBeforeMonitoring: Bool {
        if #available(iOS 17.4, *) { return false }
        return true
    }

    private func evaluate(_ activity: DeviceActivityName, reason: String) {
        guard let parsed = ActivityNames.parse(activity.rawValue),
              let shared = SharedStore() else { return }
        let kind = parsed.kind == .schedule ? "schedule" : "day"
        ShieldEnforcer.evaluate(
            profileId: parsed.profileId, shared: shared, reason: "\(kind) \(reason)"
        )
    }
}
