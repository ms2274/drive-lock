import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The block screen iOS shows when a shielded app is opened during a drive. Look only: this
/// extension can't write anything back to the app (tried in milestone (c)).
final class DriveShieldConfiguration: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration { make() }
    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration { make() }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { make() }
    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration { make() }

    private func make() -> ShieldConfiguration {
        let icon = UIImage(systemName: "lock.fill")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 56, weight: .semibold))
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.02, green: 0.05, blue: 0.08, alpha: 0.92),
            icon: icon,
            title: ShieldConfiguration.Label(text: "You're driving", color: .white),
            subtitle: ShieldConfiguration.Label(
                text: "Stay focused. This app opens again when your drive ends.",
                color: UIColor(white: 1, alpha: 0.7)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "OK", color: .black),
            primaryButtonBackgroundColor: .white)
    }
}
