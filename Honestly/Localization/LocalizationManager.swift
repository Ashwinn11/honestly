import SwiftUI
import Combine

/// Single source of truth for the app's current language. Persists the choice,
/// flips the resource bundle, and drives a full UI rebuild when it changes.
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published private(set) var language: AppLanguage

    private static let storageKey = AppConstants.keyAppLanguage

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey)
        let initial = saved.flatMap(AppLanguage.init(rawValue:)) ?? AppLanguage.deviceDefault
        self.language = initial
        Bundle.setLanguage(initial.lprojName)
        persist(initial)
    }

    func setLanguage(_ language: AppLanguage) {
        guard language != self.language else { return }
        Bundle.setLanguage(language.lprojName)
        persist(language)
        self.language = language
    }

    private func persist(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        // Mirror to the app group so extensions (e.g. the Shield) can read it.
        UserDefaults(suiteName: AppConstants.appGroupIdentifier)?
            .set(language.rawValue, forKey: Self.storageKey)
    }

    /// SwiftUI `Locale` to drive date/number formatting and layout direction.
    var locale: Locale { Locale(identifier: language.rawValue) }
    var layoutDirection: LayoutDirection { language.isRTL ? .rightToLeft : .leftToRight }

    /// The bundle for the selected language. Resolving strings through this is
    /// what makes the in-app picker apply to `String(localized:)`-style lookups,
    /// which otherwise follow the *system* language, not our override.
    var selectedBundle: Bundle {
        let candidates = [language.lprojName, String(language.rawValue.prefix(2))]
        for name in candidates {
            if let path = Bundle.main.path(forResource: name, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return .main
    }
}

/// Localized string for the user-selected in-app language. Use this instead of
/// `String(localized:)` for any non-`Text` string (model values, computed
/// labels, notifications) so it honors the in-app language picker.
func L(_ key: String) -> String {
    LocalizationManager.shared.selectedBundle.localizedString(forKey: key, value: key, table: nil)
}

/// The locale for the user's chosen in-app language. Use to drive live date /
/// number formatting (`.formatted(...).locale(appLocale)`) so dates follow the
/// picker instead of only the system language.
var appLocale: Locale { LocalizationManager.shared.locale }

extension View {
    /// Apply the selected language to a view tree: locale, layout direction, and
    /// an identity tied to the language so the whole tree rebuilds on change.
    func localized(_ manager: LocalizationManager) -> some View {
        self
            .environment(\.locale, manager.locale)
            .environment(\.layoutDirection, manager.layoutDirection)
            .environmentObject(manager)
            .id(manager.language)
    }
}
