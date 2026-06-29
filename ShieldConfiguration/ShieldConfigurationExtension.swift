import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    /// Honestly's morning shield — same look regardless of what's being shielded.
    private func honestlyShield() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,   // force light regardless of device
            backgroundColor: UIColor(red: 1.0, green: 0.42, blue: 0, alpha: 1),
            icon: UIImage(systemName: "sunrise.fill"),
            title: ShieldConfiguration.Label(text: "Finish your morning ritual first", color: .white),
            subtitle: ShieldConfiguration.Label(text: "Open Honestly to unlock your apps.", color: UIColor.white.withAlphaComponent(0.85)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Open Honestly", color: .black),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: nil
        )
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        honestlyShield()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        honestlyShield()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        honestlyShield()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        honestlyShield()
    }
}
