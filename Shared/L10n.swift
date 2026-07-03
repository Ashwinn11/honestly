import Foundation

/// Lightweight localization shared by the app and the shield extension. The shield has no
/// access to the app's SwiftUI environment, so strings it shows route through here and read
/// the user's stored language from the app group. English is the complete table; Spanish
/// covers the strings shown outside the app (the shield) plus core chrome.
enum L10n {
    static func t(_ key: String) -> String {
        let lang = SharedState.language
        return strings[lang]?[key] ?? strings["en"]?[key] ?? key
    }

    private static let strings: [String: [String: String]] = [
        "en": [
            "shield.title":     "The world can wait.",
            "shield.subtitle":  "Write your morning page in Honestly, and your apps wake up.",
            "shield.primary":   "Do my ritual",
            "shield.secondary": "Not yet",
        ],
        "es": [
            "shield.title":     "El mundo puede esperar.",
            "shield.subtitle":  "Escribe tu página matutina en Honestly y tus apps despertarán.",
            "shield.primary":   "Hacer mi ritual",
            "shield.secondary": "Todavía no",
        ],
    ]
}
