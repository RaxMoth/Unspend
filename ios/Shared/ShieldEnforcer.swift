import FamilyControls
import Foundation
import ManagedSettings

/// Turns a profile's rules into a shield — the only code that writes to a
/// profile's `ManagedSettingsStore`.
///
/// Used by the app (on activation, task changes and every sync) and by the
/// monitor extension (on every DeviceActivity callback). `evaluate` is
/// idempotent, so it does not matter who calls it or how often.
enum ShieldEnforcer {
    enum Outcome: Equatable {
        case shielded
        case cleared
        /// Rules or selection could not be read; the store was left as it was.
        case skipped
    }

    /// ManagedSettings accepts at most this many individually picked apps
    /// (and as many websites) per store.
    static let maxTokensPerKind = 50

    static func store(for profileId: String) -> ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(ActivityNames.store(profileId)))
    }

    static func selection(for profileId: String, in shared: SharedStore) -> FamilyActivitySelection? {
        guard let data = shared.selectionData(for: profileId) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    static func isEmpty(_ selection: FamilyActivitySelection) -> Bool {
        selection.applicationTokens.isEmpty
            && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
    }

    /// Applies or lifts the profile's shield according to its rules.
    ///
    /// Never guesses: when the rules or the selection cannot be read (for
    /// example a stale monitor firing for a profile that is no longer
    /// active) nothing is changed.
    @discardableResult
    static func evaluate(
        profileId: String,
        shared: SharedStore,
        now: Date = Date(),
        reason: String
    ) -> Outcome {
        guard let rules = shared.rules(for: profileId),
              let selection = selection(for: profileId, in: shared),
              !isEmpty(selection) else {
            shared.log("\(reason) \(short(profileId)): skipped, nothing to enforce", now: now)
            return .skipped
        }

        let shouldShield = ShieldPolicy.shouldShield(
            rules: rules,
            limitReachedDay: shared.limitReachedDay(for: profileId),
            now: now
        )
        if shouldShield {
            apply(selection, to: profileId)
        } else {
            clear(profileId)
        }
        shared.log("\(reason) \(short(profileId)): \(shouldShield ? "shielded" : "open")", now: now)
        return shouldShield ? .shielded : .cleared
    }

    /// Blocks the selected apps, their categories and the selected websites.
    static func apply(_ selection: FamilyActivitySelection, to profileId: String) {
        let store = store(for: profileId)
        let apps = selection.applicationTokens
        let categories = selection.categoryTokens
        let domains = selection.webDomainTokens

        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomains = domains.isEmpty ? nil : domains
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
    }

    static func clear(_ profileId: String) {
        store(for: profileId).clearAllSettings()
    }

    /// Whether the profile's store currently shields anything.
    static func isShielded(_ profileId: String) -> Bool {
        let shield = store(for: profileId).shield
        if shield.applications?.isEmpty == false { return true }
        if shield.webDomains?.isEmpty == false { return true }
        return shield.applicationCategories != nil || shield.webDomainCategories != nil
    }

    // MARK: - Uninstall protection

    private static var removalLockStore: ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(ActivityNames.removalLockStore))
    }

    /// Locks or unlocks deleting apps according to `shouldLockAppRemoval`.
    /// Called by the app whenever the set of active profiles or the setting
    /// changes.
    static func updateRemovalLock(shared: SharedStore) {
        removalLockStore.application.denyAppRemoval = shared.shouldLockAppRemoval ? true : nil
    }

    static func clearRemovalLock() {
        removalLockStore.clearAllSettings()
    }

    static var isRemovalLocked: Bool {
        removalLockStore.application.denyAppRemoval == true
    }

    /// Profile ids are long; the log only needs enough to tell them apart.
    private static func short(_ profileId: String) -> String {
        String(profileId.suffix(6))
    }
}
