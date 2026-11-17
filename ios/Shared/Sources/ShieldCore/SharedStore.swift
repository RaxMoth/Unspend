import Foundation

/// Text shown on the shield screen. The app pushes the strings for its
/// current in-app language; the shield extension only fills in the blanks.
struct ShieldStrings: Codable, Equatable {
    /// `{app}` is replaced with the blocked app or website.
    var titleTemplate: String
    /// `{profile}` is replaced with the name of the blocking profile.
    var subtitleTemplate: String
    /// Used when the blocking profile cannot be determined.
    var subtitleGeneric: String
    var button: String
    var appFallback: String
    var websiteFallback: String

    static let english = ShieldStrings(
        titleTemplate: "{app} is blocked",
        subtitleTemplate: "Blocked by “{profile}” in Unspend",
        subtitleGeneric: "Blocked by Unspend",
        button: "Go Back",
        appFallback: "This app",
        websiteFallback: "This website"
    )

    func title(for name: String?, isWebsite: Bool) -> String {
        let shown = (name?.isEmpty == false) ? name! : (isWebsite ? websiteFallback : appFallback)
        return titleTemplate.replacingOccurrences(of: "{app}", with: shown)
    }

    func subtitle(profileName: String?) -> String {
        guard let profileName, !profileName.isEmpty else { return subtitleGeneric }
        return subtitleTemplate.replacingOccurrences(of: "{profile}", with: profileName)
    }
}

/// Everything Unspend keeps in the App Group shared by the app and its
/// extensions.
///
/// Ownership — each value has exactly one writer, so the app and the
/// extensions never race on a read-modify-write:
///   • `blockedApps_<id>`      app (picker)   — the profile's app selection
///   • `rules_<id>`            app            — `ProfileRules` snapshot
///   • `activeProfileIds`      app            — profiles currently active
///   • `shieldStrings`         app            — localized shield text
///   • `removalLockEnabled`    app            — uninstall protection on/off
///   • `limitReachedDay_<id>`  extension      — day the usage limit was hit
///   • `eventLog`              both           — best-effort diagnostics only
struct SharedStore {
    static let appGroupID = "group.com.maxroth.backyourtime"
    static let maxLogEntries = 30

    private enum Key {
        static let selectionPrefix = "blockedApps_"
        static let rulesPrefix = "rules_"
        static let limitReachedDayPrefix = "limitReachedDay_"
        static let activeProfileIds = "activeProfileIds"
        static let shieldStrings = "shieldStrings"
        static let removalLockEnabled = "removalLockEnabled"
        static let eventLog = "eventLog"
        /// Written by builds that predate the rule engine.
        static let legacy = ["activeProfileId", "activeProfileName", "blockedApps"]
    }

    let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// Nil when the App Group is unavailable (entitlement missing).
    init?(suiteName: String = SharedStore.appGroupID) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        self.defaults = defaults
    }

    // MARK: Selection (opaque FamilyActivitySelection JSON)

    func selectionData(for profileId: String) -> Data? {
        defaults.data(forKey: Key.selectionPrefix + profileId)
    }

    func setSelectionData(_ data: Data, for profileId: String) {
        defaults.set(data, forKey: Key.selectionPrefix + profileId)
    }

    // MARK: Rules

    func rules(for profileId: String) -> ProfileRules? {
        guard let data = defaults.data(forKey: Key.rulesPrefix + profileId) else { return nil }
        return try? JSONDecoder().decode(ProfileRules.self, from: data)
    }

    func saveRules(_ rules: ProfileRules, for profileId: String) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        defaults.set(data, forKey: Key.rulesPrefix + profileId)
    }

    // MARK: Usage limit fact

    func limitReachedDay(for profileId: String) -> String? {
        defaults.string(forKey: Key.limitReachedDayPrefix + profileId)
    }

    func setLimitReachedDay(_ day: String?, for profileId: String) {
        let key = Key.limitReachedDayPrefix + profileId
        if let day { defaults.set(day, forKey: key) } else { defaults.removeObject(forKey: key) }
    }

    // MARK: Active profiles

    var activeProfileIds: [String] {
        defaults.stringArray(forKey: Key.activeProfileIds) ?? []
    }

    func setActive(_ active: Bool, profileId: String) {
        var ids = activeProfileIds.filter { $0 != profileId }
        if active { ids.append(profileId) }
        defaults.set(ids, forKey: Key.activeProfileIds)
    }

    // MARK: Uninstall protection

    /// Whether the user wants deleting apps to be locked while a profile is
    /// active. On unless switched off.
    var removalLockEnabled: Bool {
        defaults.object(forKey: Key.removalLockEnabled) as? Bool ?? true
    }

    func setRemovalLockEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Key.removalLockEnabled)
    }

    /// Deleting apps is locked while at least one profile is active, so
    /// that removing Unspend is not a way around a running block. iOS can
    /// only lock deleting for every app at once.
    var shouldLockAppRemoval: Bool {
        removalLockEnabled && !activeProfileIds.isEmpty
    }

    // MARK: Shield text

    var shieldStrings: ShieldStrings {
        guard let data = defaults.data(forKey: Key.shieldStrings),
              let strings = try? JSONDecoder().decode(ShieldStrings.self, from: data) else {
            return .english
        }
        return strings
    }

    func saveShieldStrings(_ strings: ShieldStrings) {
        guard let data = try? JSONEncoder().encode(strings) else { return }
        defaults.set(data, forKey: Key.shieldStrings)
    }

    // MARK: Removal

    /// Forgets that a profile is active: rules, usage fact and membership.
    /// The app selection is kept so the profile can be activated again.
    func removeActivation(for profileId: String) {
        defaults.removeObject(forKey: Key.rulesPrefix + profileId)
        defaults.removeObject(forKey: Key.limitReachedDayPrefix + profileId)
        setActive(false, profileId: profileId)
    }

    /// Removes everything stored for a profile, including its app selection.
    func removeProfile(_ profileId: String) {
        removeActivation(for: profileId)
        defaults.removeObject(forKey: Key.selectionPrefix + profileId)
    }

    /// Every profile id that has anything stored in the App Group.
    func knownProfileIds() -> [String] {
        var ids = Set(activeProfileIds)
        let prefixes = [Key.selectionPrefix, Key.rulesPrefix, Key.limitReachedDayPrefix]
        for key in defaults.dictionaryRepresentation().keys {
            for prefix in prefixes where key.hasPrefix(prefix) {
                ids.insert(String(key.dropFirst(prefix.count)))
            }
        }
        return ids.sorted()
    }

    /// Removes every value Unspend has stored in the App Group.
    func removeEverything() {
        for id in knownProfileIds() { removeProfile(id) }
        let keys = [
            Key.activeProfileIds, Key.shieldStrings, Key.removalLockEnabled, Key.eventLog,
        ]
        for key in keys + Key.legacy {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: Diagnostics

    /// Most recent events, oldest first. What the extension does is otherwise
    /// invisible, so both sides leave a short trail here.
    var eventLog: [String] {
        defaults.stringArray(forKey: Key.eventLog) ?? []
    }

    func log(_ message: String, now: Date = Date()) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM-dd HH:mm:ss"
        var entries = eventLog
        entries.append("\(formatter.string(from: now)) \(message)")
        defaults.set(Array(entries.suffix(Self.maxLogEntries)), forKey: Key.eventLog)
    }
}
