import DeviceActivity
import FamilyControls
import Flutter
import Foundation
import ManagedSettings
import UIKit

/// Bridge between Dart and the Screen Time frameworks.
///
/// Dart states intents ("activate this profile with these rules"); this class
/// owns how they map onto the App Group snapshot, the DeviceActivity monitors
/// and the profile's shield. The blocking rule itself lives in `ShieldPolicy`
/// and is applied by `ShieldEnforcer`, shared with the monitor extension.
///
/// Error codes returned to Dart:
///   NOT_AUTHORIZED, NO_SELECTION, TOO_MANY_APPS, SCHEDULE_TOO_SHORT,
///   TOO_MANY_ACTIVITIES, MONITOR_FAILED, NO_APP_GROUP, INVALID_ARGS,
///   PROFILE_ACTIVE, REVOKE_FAILED, and from requesting access:
///   NOT_CHILD_ACCOUNT, AUTH_CONFLICT, NETWORK
final class ScreenTimeChannel {
    static let channelName = "com.maxroth.backyourtime/screentime"

    private struct ChannelError: Error {
        let code: String
        let message: String

        static let noAppGroup = ChannelError(
            code: "NO_APP_GROUP", message: "The shared App Group is not available")
        static let notAuthorized = ChannelError(
            code: "NOT_AUTHORIZED", message: "Screen Time access has not been granted")
        static let noSelection = ChannelError(
            code: "NO_SELECTION", message: "No apps selected for this profile")
        static let tooManyApps = ChannelError(
            code: "TOO_MANY_APPS", message: "Too many individually selected apps or websites")
        static let scheduleTooShort = ChannelError(
            code: "SCHEDULE_TOO_SHORT", message: "The schedule must be at least 15 minutes long")

        static func invalidArgs(_ what: String) -> ChannelError {
            ChannelError(code: "INVALID_ARGS", message: what)
        }
    }

    private let center = DeviceActivityCenter()

    /// Screen Time calls talk to system daemons and can take a noticeable
    /// moment; running them here keeps the UI thread free.
    private let queue = DispatchQueue(label: "com.maxroth.backyourtime.screentime", qos: .userInitiated)

    func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: ScreenTimeChannel.channelName,
            binaryMessenger: registrar.messenger()
        )
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    // MARK: - Dispatch

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]

        switch call.method {
        case "authorizationStatus":
            result(Self.authorizationStatus)

        case "requestAuthorization":
            let member: FamilyControlsMember = (args["member"] as? String) == "child" ? .child : .individual
            requestAuthorization(for: member, result: result)

        case "revokeAuthorization":
            revokeAuthorization(result: result)

        case "openSettings":
            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                result(false)
                return
            }
            UIApplication.shared.open(url) { opened in result(opened) }

        case "activate", "deactivate", "setTasksDone", "sync", "deleteProfile",
             "resetAll", "setShieldStrings", "setRemovalLockEnabled", "diagnostics":
            let method = call.method
            queue.async { [weak self] in
                guard let self else { return }
                let outcome: Any?
                do {
                    outcome = try self.perform(method, args: args)
                } catch let error as ChannelError {
                    outcome = FlutterError(code: error.code, message: error.message, details: nil)
                } catch {
                    outcome = FlutterError(
                        code: "MONITOR_FAILED", message: error.localizedDescription, details: nil)
                }
                DispatchQueue.main.async { result(outcome) }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func perform(_ method: String, args: [String: Any]) throws -> Any? {
        guard let shared = SharedStore() else { throw ChannelError.noAppGroup }

        switch method {
        case "activate":
            return try activate(args, shared: shared)
        case "deactivate":
            deactivate(try profileId(in: args), shared: shared)
            return true
        case "setTasksDone":
            return setTasksDone(
                try profileId(in: args), done: args["done"] as? Bool ?? false, shared: shared)
        case "sync":
            return sync(args, shared: shared)
        case "deleteProfile":
            let id = try profileId(in: args)
            deactivate(id, shared: shared)
            shared.removeProfile(id)
            return true
        case "resetAll":
            resetAll(extraProfileIds: args["profileIds"] as? [String] ?? [], shared: shared)
            return true
        case "setShieldStrings":
            try setShieldStrings(args, shared: shared)
            return true
        case "setRemovalLockEnabled":
            shared.setRemovalLockEnabled(args["enabled"] as? Bool ?? true)
            ShieldEnforcer.updateRemovalLock(shared: shared)
            return true
        case "diagnostics":
            return diagnostics(shared: shared)
        default:
            return FlutterMethodNotImplemented
        }
    }

    private func profileId(in args: [String: Any]) throws -> String {
        guard let id = args["profileId"] as? String, !id.isEmpty else {
            throw ChannelError.invalidArgs("Missing profileId")
        }
        return id
    }

    // MARK: - Authorization

    private static var isAuthorized: Bool {
        AuthorizationCenter.shared.authorizationStatus == .approved
    }

    private static var authorizationStatus: String {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved: return "approved"
        case .denied: return "denied"
        case .notDetermined: return "notDetermined"
        @unknown default: return "notDetermined"
        }
    }

    /// Asks for Screen Time access.
    ///
    /// `.individual`: the person using the phone approves for themselves and
    /// can withdraw it in Settings. `.child`: a parent or guardian approves
    /// with their Apple Account on a child's device in Family Sharing; iOS
    /// then keeps the child from deleting the app or withdrawing access.
    private func requestAuthorization(for member: FamilyControlsMember, result: @escaping FlutterResult) {
        #if targetEnvironment(simulator)
        // Family Controls is not available in the Simulator; the request
        // never completes there.
        result("denied")
        #else
        Task { @MainActor in
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: member)
                result("approved")
            } catch let error as FamilyControlsError {
                switch error {
                case .invalidAccountType where member == .child:
                    result(FlutterError(
                        code: "NOT_CHILD_ACCOUNT",
                        message: "This device is not signed in as a child in Family Sharing",
                        details: nil))
                case .authorizationConflict:
                    result(FlutterError(
                        code: "AUTH_CONFLICT",
                        message: "Another app already manages Screen Time on this device",
                        details: nil))
                case .networkError:
                    result(FlutterError(
                        code: "NETWORK", message: "No connection to approve access", details: nil))
                default:
                    result(Self.isAuthorized ? "approved" : "denied")
                }
            } catch {
                result(Self.isAuthorized ? "approved" : "denied")
            }
        }
        #endif
    }

    /// Gives Screen Time access back, so it can be requested again for a
    /// different kind of user. Refused while a profile is active: iOS lifts
    /// every block when access goes away.
    private func revokeAuthorization(result: @escaping FlutterResult) {
        if let shared = SharedStore(), !shared.activeProfileIds.isEmpty {
            result(FlutterError(
                code: "PROFILE_ACTIVE", message: "Deactivate every profile first", details: nil))
            return
        }
        #if targetEnvironment(simulator)
        result(true)
        #else
        AuthorizationCenter.shared.revokeAuthorization { outcome in
            DispatchQueue.main.async {
                switch outcome {
                case .success:
                    result(true)
                case .failure(let error):
                    result(FlutterError(
                        code: "REVOKE_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
        #endif
    }

    // MARK: - Activation

    private func activate(_ args: [String: Any], shared: SharedStore) throws -> [String: Any] {
        let id = try profileId(in: args)
        guard Self.isAuthorized else { throw ChannelError.notAuthorized }
        guard let selection = ShieldEnforcer.selection(for: id, in: shared),
              !ShieldEnforcer.isEmpty(selection) else { throw ChannelError.noSelection }
        guard selection.applicationTokens.count <= ShieldEnforcer.maxTokensPerKind,
              selection.webDomainTokens.count <= ShieldEnforcer.maxTokensPerKind else {
            throw ChannelError.tooManyApps
        }

        let now = Date()
        let rules = try makeRules(args, now: now)

        // Start from a clean slate, then write the snapshot BEFORE registering
        // the monitors: registering can wake the extension straight away and
        // it must find the rules it is supposed to enforce.
        stopMonitors(for: id)
        shared.setLimitReachedDay(nil, for: id)
        shared.saveRules(rules, for: id)
        shared.setActive(true, profileId: id)

        do {
            try startMonitors(for: id, rules: rules, selection: selection)
        } catch {
            deactivate(id, shared: shared)
            shared.log("activate \(id.suffix(6)): failed, \(error.localizedDescription)", now: now)
            throw Self.channelError(for: error)
        }

        ShieldEnforcer.evaluate(profileId: id, shared: shared, now: now, reason: "activate")
        ShieldEnforcer.updateRemovalLock(shared: shared)
        return status(of: id, shared: shared, now: now)
    }

    private func makeRules(_ args: [String: Any], now: Date) throws -> ProfileRules {
        var rules = ProfileRules(
            name: args["name"] as? String ?? "",
            taskModeEnabled: args["taskModeEnabled"] as? Bool ?? false
        )

        if let start = args["scheduleStartMinute"] as? Int,
           let end = args["scheduleEndMinute"] as? Int {
            let validRange = 0..<ShieldPolicy.minutesPerDay
            guard validRange.contains(start), validRange.contains(end) else {
                throw ChannelError.invalidArgs("Schedule times are out of range")
            }
            guard ShieldPolicy.isValidSchedule(start: start, end: end) else {
                throw ChannelError.scheduleTooShort
            }
            rules.scheduleStartMinute = start
            rules.scheduleEndMinute = end
        }

        if let limit = args["usageLimitMinutes"] as? Int {
            guard (1..<ShieldPolicy.minutesPerDay).contains(limit) else {
                throw ChannelError.invalidArgs("Usage limit is out of range")
            }
            rules.usageLimitMinutes = limit
            rules.limitMonitorStartedAt = now
        }

        if rules.taskModeEnabled, args["tasksDone"] as? Bool == true {
            rules.tasksDoneDay = DayKey.string(for: now)
        }
        return rules
    }

    private func deactivate(_ profileId: String, shared: SharedStore) {
        stopMonitors(for: profileId)
        ShieldEnforcer.clear(profileId)
        shared.removeActivation(for: profileId)
        ShieldEnforcer.updateRemovalLock(shared: shared)
    }

    // MARK: - Tasks

    private func setTasksDone(_ profileId: String, done: Bool, shared: SharedStore) -> [String: Any] {
        let now = Date()
        if var rules = shared.rules(for: profileId) {
            rules.tasksDoneDay = done ? DayKey.string(for: now) : nil
            shared.saveRules(rules, for: profileId)
            ShieldEnforcer.evaluate(profileId: profileId, shared: shared, now: now, reason: "tasks")
        }
        return status(of: profileId, shared: shared, now: now)
    }

    // MARK: - Sync

    /// Brings the system in line with what the app believes and reports back.
    ///
    /// `profiles` lists the profiles the app shows as active, each with
    /// whether today's tasks are done. Anything active here but unknown to
    /// the app is switched off; anything the app lists that cannot be
    /// enforced any more is left out of the reply, so the app can show it as
    /// inactive.
    private func sync(_ args: [String: Any], shared: SharedStore) -> [String: Any] {
        let entries = args["profiles"] as? [[String: Any]] ?? []
        var tasksDone: [String: Bool] = [:]
        for entry in entries {
            if let id = entry["profileId"] as? String {
                tasksDone[id] = entry["tasksDone"] as? Bool ?? false
            }
        }

        let now = Date()
        let today = DayKey.string(for: now)
        let monitored = Set(center.activities.map(\.rawValue))
        var reply: [String: Any] = [:]

        for id in shared.activeProfileIds {
            guard let done = tasksDone[id],
                  var rules = shared.rules(for: id),
                  let selection = ShieldEnforcer.selection(for: id, in: shared),
                  !ShieldEnforcer.isEmpty(selection) else {
                deactivate(id, shared: shared)
                shared.log("sync \(id.suffix(6)): switched off, not enforceable", now: now)
                continue
            }

            var changed = false
            let doneDay = (rules.taskModeEnabled && done) ? today : nil
            if rules.tasksDoneDay != doneDay {
                rules.tasksDoneDay = doneDay
                changed = true
            }

            // iOS can drop monitors (for example after an update); put back
            // whatever this profile needs.
            if Self.isAuthorized, !expectedActivities(for: id, rules: rules).isSubset(of: monitored) {
                stopMonitors(for: id)
                if rules.hasUsageLimit {
                    rules.limitMonitorStartedAt = now
                    changed = true
                }
                if changed { shared.saveRules(rules, for: id) }
                changed = false
                do {
                    try startMonitors(for: id, rules: rules, selection: selection)
                    shared.log("sync \(id.suffix(6)): monitors restored", now: now)
                } catch {
                    shared.log("sync \(id.suffix(6)): restore failed, \(error.localizedDescription)", now: now)
                }
            }
            if changed { shared.saveRules(rules, for: id) }

            ShieldEnforcer.evaluate(profileId: id, shared: shared, now: now, reason: "sync")
            reply[id] = status(of: id, shared: shared, now: now)
        }
        ShieldEnforcer.updateRemovalLock(shared: shared)
        return reply
    }

    private func status(of profileId: String, shared: SharedStore, now: Date) -> [String: Any] {
        [
            "shielded": ShieldEnforcer.isShielded(profileId),
            "limitReached": shared.limitReachedDay(for: profileId) == DayKey.string(for: now),
        ]
    }

    // MARK: - Monitors

    private func expectedActivities(for profileId: String, rules: ProfileRules) -> Set<String> {
        var names: Set<String> = []
        if rules.hasSchedule { names.insert(ActivityNames.schedule(profileId)) }
        if rules.needsDayActivity { names.insert(ActivityNames.day(profileId)) }
        return names
    }

    private func startMonitors(
        for profileId: String,
        rules: ProfileRules,
        selection: FamilyActivitySelection
    ) throws {
        if let start = rules.scheduleStartMinute, let end = rules.scheduleEndMinute {
            try center.startMonitoring(
                DeviceActivityName(ActivityNames.schedule(profileId)),
                during: DeviceActivitySchedule(
                    intervalStart: DateComponents(hour: start / 60, minute: start % 60),
                    intervalEnd: DateComponents(hour: end / 60, minute: end % 60),
                    repeats: true
                )
            )
        }

        if rules.needsDayActivity {
            // One interval per calendar day: it carries the usage threshold
            // and wakes the extension at midnight for the daily reset.
            var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
            if let limit = rules.usageLimitMinutes {
                events[DeviceActivityEvent.Name(ActivityNames.limitReachedEvent)] =
                    limitEvent(for: selection, minutes: limit)
            }
            try center.startMonitoring(
                DeviceActivityName(ActivityNames.day(profileId)),
                during: DeviceActivitySchedule(
                    intervalStart: DateComponents(hour: 0, minute: 0),
                    intervalEnd: DateComponents(hour: 23, minute: 59),
                    repeats: true
                ),
                events: events
            )
        }
    }

    private func limitEvent(for selection: FamilyActivitySelection, minutes: Int) -> DeviceActivityEvent {
        let threshold = DateComponents(hour: minutes / 60, minute: minutes % 60)
        if #available(iOS 17.4, *) {
            // Count from now on, not from midnight: usage from before the
            // profile was activated must not use up the budget.
            return DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: threshold,
                includesPastActivity: false
            )
        }
        return DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: threshold
        )
    }

    private func stopMonitors(for profileId: String) {
        center.stopMonitoring([
            DeviceActivityName(ActivityNames.schedule(profileId)),
            DeviceActivityName(ActivityNames.day(profileId)),
            DeviceActivityName(ActivityNames.legacyLimit(profileId)),
        ])
    }

    private static func channelError(for error: Error) -> ChannelError {
        if let known = error as? ChannelError { return known }
        if let monitoring = error as? DeviceActivityCenter.MonitoringError {
            switch monitoring {
            case .excessiveActivities:
                return ChannelError(
                    code: "TOO_MANY_ACTIVITIES", message: "Too many profiles are monitored at once")
            case .intervalTooShort:
                return .scheduleTooShort
            case .unauthorized:
                return .notAuthorized
            default:
                break
            }
        }
        return ChannelError(code: "MONITOR_FAILED", message: error.localizedDescription)
    }

    // MARK: - Reset

    /// Removes every block and every stored value. `extraProfileIds` covers
    /// profiles the app knows about that left no trace in the App Group.
    private func resetAll(extraProfileIds: [String], shared: SharedStore) {
        center.stopMonitoring()
        for id in Set(shared.knownProfileIds()).union(extraProfileIds) {
            ShieldEnforcer.clear(id)
        }
        // Stores used by builds that predate per-profile stores.
        ManagedSettingsStore().clearAllSettings()
        ManagedSettingsStore(named: ManagedSettingsStore.Name("unspend")).clearAllSettings()
        ShieldEnforcer.clearRemovalLock()
        shared.removeEverything()
    }

    // MARK: - Shield text

    private func setShieldStrings(_ args: [String: Any], shared: SharedStore) throws {
        guard let data = try? JSONSerialization.data(withJSONObject: args),
              let strings = try? JSONDecoder().decode(ShieldStrings.self, from: data) else {
            throw ChannelError.invalidArgs("Incomplete shield strings")
        }
        shared.saveShieldStrings(strings)
    }

    // MARK: - Diagnostics

    private func diagnostics(shared: SharedStore) -> [String: Any] {
        let active = shared.activeProfileIds
        return [
            "authorization": Self.authorizationStatus,
            "activeProfileIds": active,
            "shieldedProfileIds": active.filter(ShieldEnforcer.isShielded),
            "removalLocked": ShieldEnforcer.isRemovalLocked,
            "monitoredActivities": center.activities.map(\.rawValue).sorted(),
            "eventLog": shared.eventLog,
        ]
    }
}
