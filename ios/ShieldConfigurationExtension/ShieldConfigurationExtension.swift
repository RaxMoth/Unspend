import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Supplies the screen iOS shows instead of a blocked app or website.
///
/// The wording comes from the app (in its current language) through the App
/// Group. The subtitle names the profile that is actually blocking the item,
/// found by looking for it in each active profile's shield.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration(name: application.localizedDisplayName, isWebsite: false) { shield in
            guard let token = application.token else { return false }
            return shield.applications?.contains(token) == true
        }
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration(name: application.localizedDisplayName, isWebsite: false) { shield in
            guard let token = category.token,
                  case .specific(let tokens, _)? = shield.applicationCategories else { return false }
            return tokens.contains(token)
        }
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration(name: webDomain.domain, isWebsite: true) { shield in
            guard let token = webDomain.token else { return false }
            return shield.webDomains?.contains(token) == true
        }
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration(name: webDomain.domain, isWebsite: true) { shield in
            guard let token = category.token,
                  case .specific(let tokens, _)? = shield.webDomainCategories else { return false }
            return tokens.contains(token)
        }
    }

    // MARK: - Helpers

    private func makeConfiguration(
        name: String?,
        isWebsite: Bool,
        isBlockedBy: (ShieldSettings) -> Bool
    ) -> ShieldConfiguration {
        let shared = SharedStore()
        let strings = shared?.shieldStrings ?? .english
        let profileName = shared.flatMap { blockingProfileName(in: $0, isBlockedBy: isBlockedBy) }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterial,
            backgroundColor: UIColor.black.withAlphaComponent(0.85),
            icon: UIImage(systemName: "shield.checkered"),
            title: ShieldConfiguration.Label(
                text: strings.title(for: name, isWebsite: isWebsite),
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: strings.subtitle(profileName: profileName),
                color: .lightGray
            ),
            primaryButtonLabel: ShieldConfiguration.Label(text: strings.button, color: .white),
            primaryButtonBackgroundColor: .systemBlue,
            secondaryButtonLabel: nil
        )
    }

    /// Name of the active profile whose shield contains the blocked item.
    /// With a single active profile the answer is known without looking.
    private func blockingProfileName(
        in shared: SharedStore,
        isBlockedBy: (ShieldSettings) -> Bool
    ) -> String? {
        let active = shared.activeProfileIds
        if active.count > 1 {
            for id in active {
                let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(ActivityNames.store(id)))
                if isBlockedBy(store.shield), let name = shared.rules(for: id)?.name, !name.isEmpty {
                    return name
                }
            }
            return nil
        }
        return active.first.flatMap { shared.rules(for: $0)?.name }
    }
}
