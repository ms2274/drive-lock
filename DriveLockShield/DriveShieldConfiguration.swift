import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Supplies the block screen's look. Each time it is asked, that is one pickup attempt.
final class DriveShieldConfiguration: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration { make() }
    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration { make() }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { make() }
    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration { make() }

    private func make() -> ShieldConfiguration {
        ShieldAttemptLog.record()
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            title: ShieldConfiguration.Label(text: "You're driving", color: .label),
            subtitle: ShieldConfiguration.Label(
                text: "DriveLock keeps this app closed until the drive ends.", color: .secondaryLabel))
    }
}
