import Foundation

/// Uses the selected app language in code that has no SwiftUI locale environment.
enum L10n {
    static func t(_ key: String) -> String {
        localized(shieldKeys[key] ?? key)
    }

    static func localized(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: SharedState.language, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func appWaitTitle(for appName: String) -> String {
        let format = localized("%@ can wait.")
        return String(format: format, appName)
    }

    private static let shieldKeys: [String: String] = [
        "shield.title": "The world can wait.",
        "shield.subtitle": "Write your morning page in Honestly, and your apps wake up.",
        // The shield's button leaves about 108 points for its label, and iOS left-aligns a label
        // that wraps — so it's short enough to stay on one line in every language.
        "shield.primary": "Write now",
    ]
}
