import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Localize a string for the app's in-app language. The extension is a separate
/// process, so it reads the chosen language from the shared app group and looks
/// the string up in its own bundle's matching `.lproj`.
private func shieldLocalized(_ key: String) -> String {
    let group = UserDefaults(suiteName: "group.morning-journal.app")
    if let lang = group?.string(forKey: "app_language"),
       let path = Bundle.main.path(forResource: lang, ofType: "lproj")
        ?? Bundle.main.path(forResource: String(lang.prefix(2)), ofType: "lproj"),
       let bundle = Bundle(path: path) {
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
    return Bundle.main.localizedString(forKey: key, value: key, table: nil)
}

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    /// Honestly's morning shield — same look regardless of what's being shielded.
    private func honestlyShield() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,   // force light regardless of device
            backgroundColor: UIColor(red: 1.0, green: 0.42, blue: 0, alpha: 1),
            icon: UIImage(systemName: "sunrise.fill"),
            title: ShieldConfiguration.Label(text: shieldLocalized("Finish your morning ritual first"), color: .white),
            subtitle: ShieldConfiguration.Label(text: shieldLocalized("Open Honestly to unlock your apps."), color: UIColor.white.withAlphaComponent(0.85)),
            primaryButtonLabel: ShieldConfiguration.Label(text: shieldLocalized("Open Honestly"), color: .black),
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
