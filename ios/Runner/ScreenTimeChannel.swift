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
/// Names of methods, arguments, replies and error codes are in
/// `ChannelContract`, which mirrors the Dart side.
final class ScreenTimeChannel {
    private typealias Method = ChannelContract.Method
    private typealias Arg = ChannelContract.Arg
    private typealias Reply = ChannelContract.Reply
    private typealias ErrorCode = ChannelContract.ErrorCode

    private struct ChannelError: Error {
        let code: ErrorCode
        let message: String

        var flutterError: FlutterError { code.error(message) }

        static let noAppGroup = ChannelError(
            code: .noAppGroup, message: "The shared App Group is not available")
        static let notAuthorized = ChannelError(
            code: .notAuthorized, message: "Screen Time access has not been granted")
        static let noSelection = ChannelError(
            code: .noSelection, message: "No apps selected for this profile")
        static let tooManyApps = ChannelError(
            code: .tooManyApps, message: "Too many individually selected apps or websites")
        static let scheduleTooShort = ChannelError(
            code: .scheduleTooShort, message: "The schedule must be at least 15 minutes long")

        static func invalidArgs(_ what: String) -> ChannelError {
            ChannelError(code: .invalidArgs, message: what)
        }
    }

    private let center = DeviceActivityCenter()

    /// Screen Time calls talk to system daemons and can take a noticeable
    /// moment; running them here keeps the UI thread free.
    private let queue = DispatchQueue(label: ChannelContract.workQueueLabel, qos: .userInitiated)

    func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: ChannelContract.screenTimeChannel,
            binaryMessenger: registrar.messenger()
        )
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    // MARK: - Dispatch

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let method = Method(rawValue: call.method) else {
            result(FlutterMethodNotImplemented)
            return
        }
        let args = call.arguments as? [String: Any] ?? [:]

        switch method {
        case .authorizationStatus:
            result(Self.authorizationStatus)

        case .requestAuthorization:
            let wantsChild = (args[Arg.member] as? String) == Arg.memberChild
            requestAuthorization(for: wantsChild ? .child : .individual, result: result)

        case .revokeAuthorization:
            revokeAuthorization(result: result)

        case .openSettings:
            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                result(false)
                return
            }
            UIApplication.shared.open(url) { opened in result(opened) }

        case .appVersion:
            result(Self.appVersion)

        case .showPicker:
            // Served by AppPickerChannel on its own channel.
            result(FlutterMethodNotImplemented)

        case .activate, .deactivate, .setTasksDone, .sync, .deleteProfile,
             .resetAll, .setShieldStrings, .setRemovalLockEnabled, .diagnostics:
            queue.async { [weak self] in
                guard let self else { return }
                let outcome: Any?
                do {
                    outcome = try self.perform(method, args: args)
                } catch let error as ChannelError {
                    outcome = error.flutterError
                } catch {
                    outcome = ErrorCode.monitorFailed.error(error.localizedDescription)
                }
                DispatchQueue.main.async { result(outcome) }
            }
        }
    }

    /// The methods that touch the App Group, monitors or shields. Runs on
    /// the work queue.
    private func perform(_ method: Method, args: [String: Any]) throws -> Any? {
        guard let shared = SharedStore() else { throw ChannelError.noAppGroup }

        switch method {
        case .activate:
            return try activate(args, shared: shared)
        case .deactivate:
            deactivate(try profileId(in: args), shared: shared)
            return true
        case .setTasksDone:
            return setTasksDone(
                try profileId(in: args), done: args[Arg.done] as? Bool ?? false, shared: shared)
        case .sync:
            return sync(args, shared: shared)
        case .deleteProfile:
            let id = try profileId(in: args)
            deactivate(id, shared: shared)
            shared.removeProfile(id)
            return true
        case .resetAll:
            resetAll(extraProfileIds: args[Arg.profileIds] as? [String] ?? [], shared: shared)
            return true
        case .setShieldStrings:
            try setShieldStrings(args, shared: shared)
            return true
        case .setRemovalLockEnabled:
            shared.setRemovalLockEnabled(args[Arg.enabled] as? Bool ?? true)
            ShieldEnforcer.updateRemovalLock(shared: shared)
            return true
        case .diagnostics:
            return diagnostics(shared: shared)
        case .authorizationStatus, .requestAuthorization, .revokeAuthorization,
             .openSettings, .appVersion, .showPicker:
            return FlutterMethodNotImplemented
        }
    }

    private func profileId(in args: [String: Any]) throws -> String {
        guard let id = args[Arg.profileId] as? String, !id.isEmpty else {
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
        case .approved: return Reply.approved
        case .denied: return Reply.denied
        case .notDetermined: return Reply.notDetermined
        @unknown default: return Reply.notDetermined
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
        result(Reply.denied)
        #else
        Task { @MainActor in
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: member)
                result(Reply.approved)
            } catch let error as FamilyControlsError {
                switch error {
                case .invalidAccountType where member == .child:
                    result(ErrorCode.notChildAccount.error(
                        "This device is not signed in as a child in Family Sharing"))
                case .authorizationConflict:
                    result(ErrorCode.authorizationConflict.error(
                        "Another app already manages Screen Time on this device"))
                case .networkError:
                    result(ErrorCode.network.error("No connection to approve access"))
                default:
                    result(Self.isAuthorized ? Reply.approved : Reply.denied)
                }
            } catch {
                result(Self.isAuthorized ? Reply.approved : Reply.denied)
            }
        }
        #endif
    }

    /// Gives Screen Time access back, so it can be requested again for a
    /// different kind of user. Refused while a profile is active: iOS lifts
    /// every block when access goes away.
    private func revokeAuthorization(result: @escaping FlutterResult) {
        if let shared = SharedStore(), !shared.activeProfileIds.isEmpty {
            result(ErrorCode.profileActive.error("Deactivate every profile first"))
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
                    result(ErrorCode.revokeFailed.error(error.localizedDescription))
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
            name: args[Arg.name] as? String ?? "",
            taskModeEnabled: args[Arg.taskModeEnabled] as? Bool ?? false
        )

        if let start = args[Arg.scheduleStartMinute] as? Int,
           let end = args[Arg.scheduleEndMinute] as? Int {
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

        if let limit = args[Arg.usageLimitMinutes] as? Int {
            guard (1..<ShieldPolicy.minutesPerDay).contains(limit) else {
                throw ChannelError.invalidArgs("Usage limit is out of range")
            }
            rules.usageLimitMinutes = limit
            rules.limitMonitorStartedAt = now
        }

        if rules.taskModeEnabled, args[Arg.tasksDone] as? Bool == true {
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
        let entries = args[Arg.profiles] as? [[String: Any]] ?? []
        var tasksDone: [String: Bool] = [:]
        for entry in entries {
            if let id = entry[Arg.profileId] as? String {
                tasksDone[id] = entry[Arg.tasksDone] as? Bool ?? false
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
            Reply.shielded: ShieldEnforcer.isShielded(profileId),
            Reply.limitReached: shared.limitReachedDay(for: profileId) == DayKey.string(for: now),
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
                    code: .tooManyActivities, message: "Too many profiles are monitored at once")
            case .intervalTooShort:
                return .scheduleTooShort
            case .unauthorized:
                return .notAuthorized
            default:
                break
            }
        }
        return ChannelError(code: .monitorFailed, message: error.localizedDescription)
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
        ManagedSettingsStore(named: ManagedSettingsStore.Name(ActivityNames.legacyStore)).clearAllSettings()
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

    /// Version and build number of the running app, as "1.0.0 (1)".
    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private func diagnostics(shared: SharedStore) -> [String: Any] {
        let active = shared.activeProfileIds
        return [
            Reply.authorization: Self.authorizationStatus,
            Reply.activeProfileIds: active,
            Reply.shieldedProfileIds: active.filter(ShieldEnforcer.isShielded),
            Reply.removalLocked: ShieldEnforcer.isRemovalLocked,
            Reply.monitoredActivities: center.activities.map(\.rawValue).sorted(),
            Reply.eventLog: shared.eventLog,
        ]
    }
}
