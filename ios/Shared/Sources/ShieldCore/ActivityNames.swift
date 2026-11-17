import Foundation

/// Names of the DeviceActivity monitors and ManagedSettings stores Unspend
/// registers. Everything is scoped per profile so profiles never interfere.
enum ActivityNames {
    enum Kind: Equatable {
        /// The user's daily schedule window.
        case schedule
        /// 00:00–23:59 every day: carries the usage threshold and wakes the
        /// extension at midnight for the daily task and limit reset.
        case day
    }

    private static let schedulePrefix = "unspend.schedule."
    private static let dayPrefix = "unspend.day."

    static func schedule(_ profileId: String) -> String { schedulePrefix + profileId }
    static func day(_ profileId: String) -> String { dayPrefix + profileId }

    /// Monitor registered by builds that predate the rule engine. It is only
    /// ever stopped, never started.
    static func legacyLimit(_ profileId: String) -> String { "unspend.limit." + profileId }

    /// Event attached to the day activity when a usage limit is set.
    static let limitReachedEvent = "unspend.limitReached"

    /// Name of the profile's own `ManagedSettingsStore`. iOS unions the
    /// shields of all stores, so overlapping profiles block independently.
    static func store(_ profileId: String) -> String { "unspend." + profileId }

    /// Store holding the "apps cannot be deleted" restriction. Profile ids
    /// are numeric, so the name cannot collide with a profile's store.
    static let removalLockStore = "unspend.guard"

    /// Splits an activity name into its kind and profile id. Profile ids may
    /// contain dots, so only the fixed prefix is stripped.
    static func parse(_ raw: String) -> (kind: Kind, profileId: String)? {
        for (prefix, kind) in [(schedulePrefix, Kind.schedule), (dayPrefix, Kind.day)] {
            if raw.hasPrefix(prefix) {
                let id = String(raw.dropFirst(prefix.count))
                return id.isEmpty ? nil : (kind, id)
            }
        }
        return nil
    }
}
