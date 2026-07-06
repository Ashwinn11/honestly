import SwiftUI
import WidgetKit

/// Drives the in-app language. The picker writes here; the root injects `locale` + `layoutDirection`
/// into the environment so every SwiftUI `Text` re-resolves against the String Catalog **live**, no
/// relaunch. The chosen code is mirrored to the app group so the shield extension matches.
@Observable
final class LocalizationManager {

    struct Language: Identifiable, Hashable {
        let code: String
        let name: String                 // endonym, shown in the picker
        var id: String { code }
        init(_ code: String, _ name: String) { self.code = code; self.name = name }
    }

    /// The 13 in-app languages — the base languages of the App Store listing.
    static let supported: [Language] = [
        .init("en", "English"),
        .init("ar", "العربية"),
        .init("de", "Deutsch"),
        .init("es", "Español"),
        .init("fr", "Français"),
        .init("it", "Italiano"),
        .init("ja", "日本語"),
        .init("ko", "한국어"),
        .init("nl", "Nederlands"),
        .init("pt", "Português"),
        .init("ru", "Русский"),
        .init("zh-Hans", "简体中文"),
        .init("zh-Hant", "繁體中文"),
    ]

    private(set) var code: String

    init() {
        let initial = Self.resolvedInitial()
        code = initial
        // Persist the device-derived default on first launch so the shield extension matches.
        if SharedState.defaults.string(forKey: SharedState.Key.language) == nil {
            SharedState.language = initial
        }
    }

    var current: Language { Self.supported.first { $0.code == code } ?? Self.supported[0] }
    var locale: Locale { Locale(identifier: code) }
    var layoutDirection: LayoutDirection {
        Locale.Language(identifier: code).characterDirection == .rightToLeft ? .rightToLeft : .leftToRight
    }

    func select(_ language: Language) {
        guard language.code != code else { return }
        Haptics.select()
        withAnimation(Motion.gentle) {
            code = language.code
            SharedState.language = language.code
        }
        // The widget forces this same value via `.environment(\.locale, ...)`, but only re-reads
        // it whenever it next renders — without this it'd keep showing the old language until
        // some unrelated refresh (next midnight, or writing today's page) happened to trigger one.
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Saved choice if valid, else the best match for the device's preferred languages, else English.
    private static func resolvedInitial() -> String {
        if let saved = SharedState.defaults.string(forKey: SharedState.Key.language),
           supported.contains(where: { $0.code == saved }) {
            return saved
        }
        return deviceDefault()
    }

    static func deviceDefault() -> String {
        let codes = supported.map(\.code)
        for pref in Locale.preferredLanguages {
            let id = Locale(identifier: pref)
            guard let lang = id.language.languageCode?.identifier else { continue }
            if let script = id.language.script?.identifier, codes.contains("\(lang)-\(script)") {
                return "\(lang)-\(script)"
            }
            if codes.contains(lang) { return lang }
        }
        return "en"
    }
}
