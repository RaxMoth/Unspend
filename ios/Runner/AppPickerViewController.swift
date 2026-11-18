import FamilyControls
import Flutter
import SwiftUI
import UIKit

/// Text for the picker sheet, supplied by Dart in the app's current language.
struct AppPickerLabels {
    var title = "Choose Apps"
    var cancel = "Cancel"
    var save = "Save"
    var tooMany = "Too many individual apps selected. Choose whole categories instead."

    init() {}

    init(_ args: [String: Any]) {
        func text(_ key: String) -> String? {
            guard let value = args[key] as? String, !value.isEmpty else { return nil }
            return value
        }
        title = text(ChannelContract.Arg.title) ?? title
        cancel = text(ChannelContract.Arg.cancel) ?? cancel
        save = text(ChannelContract.Arg.save) ?? save
        tooMany = text(ChannelContract.Arg.tooMany) ?? tooMany
    }
}

/// Method channel that presents the system app picker for one profile.
///
/// `showPicker` answers with the number of selected items, or nil when the
/// user cancelled. It always answers exactly once.
final class AppPickerChannel {
    func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: ChannelContract.appPickerChannel,
            binaryMessenger: registrar.messenger()
        )
        channel.setMethodCallHandler { [weak self] call, result in
            guard call.method == ChannelContract.Method.showPicker.rawValue else {
                result(FlutterMethodNotImplemented)
                return
            }
            self?.showPicker(call.arguments as? [String: Any] ?? [:], result: result)
        }
    }

    private func showPicker(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let profileId = args[ChannelContract.Arg.profileId] as? String, !profileId.isEmpty else {
            result(ChannelContract.ErrorCode.invalidArgs.error("Missing profileId"))
            return
        }
        guard let shared = SharedStore() else {
            result(ChannelContract.ErrorCode.noAppGroup.error("The shared App Group is not available"))
            return
        }
        // Changing the selection of a profile that is blocking right now
        // would be a way around the block.
        guard !shared.activeProfileIds.contains(profileId) else {
            result(ChannelContract.ErrorCode.profileActive.error(
                "Deactivate the profile before changing its apps"))
            return
        }
        guard let presenter = Self.topViewController() else {
            result(ChannelContract.ErrorCode.noWindow.error("No window to present from"))
            return
        }

        let picker = AppPickerViewController(
            profileId: profileId,
            labels: AppPickerLabels(args),
            shared: shared,
            completion: { count in result(count) }
        )
        presenter.present(picker, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        var top = (windows.first(where: \.isKeyWindow) ?? windows.first)?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

/// Hosts `FamilyActivityPicker` for a single profile. The selection is stored
/// per profile, so picking apps for one profile never changes another.
final class AppPickerViewController: UIViewController {
    private let profileId: String
    private let labels: AppPickerLabels
    private let shared: SharedStore
    private var completion: ((Int?) -> Void)?
    /// What Save decided: the number of picked items. Stays nil for Cancel
    /// and for a sheet that went away by itself.
    private var savedCount: Int?

    init(
        profileId: String,
        labels: AppPickerLabels,
        shared: SharedStore,
        completion: @escaping (Int?) -> Void
    ) {
        self.profileId = profileId
        self.labels = labels
        self.shared = shared
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .formSheet
        // Swiping the sheet away would leave Dart waiting; make the user
        // choose Cancel or Save.
        isModalInPresentation = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    deinit {
        // Last resort: whatever happened to the sheet, Dart gets an answer.
        completion?(savedCount)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let pickerView = AppPickerView(
            initialSelection: ShieldEnforcer.selection(for: profileId, in: shared)
                ?? FamilyActivitySelection(),
            labels: labels,
            onSave: { [weak self] selection in self?.save(selection) },
            onCancel: { [weak self] in self?.close() }
        )
        let host = UIHostingController(rootView: pickerView)
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // UIKit calls this before the completion block of `dismiss`, and
        // also when something other than the two buttons closed the sheet.
        // Either way the sheet is gone, so Dart gets what was decided.
        if isBeingDismissed || presentingViewController == nil {
            answer()
        }
    }

    private func save(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else {
            close()
            return
        }
        shared.setSelectionData(data, for: profileId)
        savedCount = selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
        close()
    }

    private func close() {
        dismiss(animated: true) { [weak self] in self?.answer() }
    }

    /// Hands the result to Dart, once: the saved count, or nil for a cancel.
    private func answer() {
        guard let completion else { return }
        self.completion = nil
        completion(savedCount)
    }
}

private struct AppPickerView: View {
    @State private var selection: FamilyActivitySelection
    let labels: AppPickerLabels
    let onSave: (FamilyActivitySelection) -> Void
    let onCancel: () -> Void

    init(
        initialSelection: FamilyActivitySelection,
        labels: AppPickerLabels,
        onSave: @escaping (FamilyActivitySelection) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _selection = State(initialValue: initialSelection)
        self.labels = labels
        self.onSave = onSave
        self.onCancel = onCancel
    }

    /// iOS shields at most 50 individually picked apps (and 50 websites) per
    /// profile; categories have no such limit.
    private var hasTooMany: Bool {
        selection.applicationTokens.count > ShieldEnforcer.maxTokensPerKind
            || selection.webDomainTokens.count > ShieldEnforcer.maxTokensPerKind
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                FamilyActivityPicker(selection: $selection)
                if hasTooMany {
                    Text(labels.tooMany)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding()
                }
            }
            .navigationTitle(labels.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(labels.cancel, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(labels.save) { onSave(selection) }
                        .disabled(ShieldEnforcer.isEmpty(selection) || hasTooMany)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
