import Foundation
import ObjectiveC

/// Lets the app override its language at runtime (independent of the system
/// language) so the in-app picker works. We swap `Bundle.main`'s class for a
/// subclass that resolves every localized-string lookup against the selected
/// `.lproj`. Both SwiftUI `Text(LocalizedStringKey)` and `String(localized:)`
/// go through this, so one switch covers the whole app.
final class AnyLanguageBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let path = objc_getAssociatedObject(self, &Bundle.languageBundleKey) as? String,
              let bundle = Bundle(path: path) else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    fileprivate static var languageBundleKey: UInt8 = 0

    private static let swizzleOnce: Void = {
        object_setClass(Bundle.main, AnyLanguageBundle.self)
    }()

    /// Point `Bundle.main` at the `.lproj` for `language` (e.g. "fr", "pt-BR").
    /// Falls back to the base language folder, then to the default bundle.
    static func setLanguage(_ language: String) {
        _ = swizzleOnce
        var path = Bundle.main.path(forResource: language, ofType: "lproj")
        if path == nil {
            let base = String(language.prefix(2))
            path = Bundle.main.path(forResource: base, ofType: "lproj")
        }
        objc_setAssociatedObject(Bundle.main, &languageBundleKey, path, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
