import Foundation

/// The 14 languages the app ships to the App Store, grouped so regional
/// storefront variants (en-US/GB/CA/AU, es-ES/MX, fr-FR/CA) share one translation.
enum AppLanguage: String, CaseIterable, Identifiable {
    case en
    case ar
    case de
    case es
    case fr
    case it
    case ja
    case ko
    case nl
    case ptBR = "pt-BR"
    case ptPT = "pt-PT"
    case ru
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"

    var id: String { rawValue }

    /// Name shown in the picker, written in its own language.
    var nativeName: String {
        switch self {
        case .en:     return "English"
        case .ar:     return "العربية"
        case .de:     return "Deutsch"
        case .es:     return "Español"
        case .fr:     return "Français"
        case .it:     return "Italiano"
        case .ja:     return "日本語"
        case .ko:     return "한국어"
        case .nl:     return "Nederlands"
        case .ptBR:   return "Português (Brasil)"
        case .ptPT:   return "Português"
        case .ru:     return "Русский"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        }
    }

    var flag: String {
        switch self {
        case .en:     return "🇺🇸"
        case .ar:     return "🇸🇦"
        case .de:     return "🇩🇪"
        case .es:     return "🇪🇸"
        case .fr:     return "🇫🇷"
        case .it:     return "🇮🇹"
        case .ja:     return "🇯🇵"
        case .ko:     return "🇰🇷"
        case .nl:     return "🇳🇱"
        case .ptBR:   return "🇧🇷"
        case .ptPT:   return "🇵🇹"
        case .ru:     return "🇷🇺"
        case .zhHans: return "🇨🇳"
        case .zhHant: return "🇹🇼"
        }
    }

    var isRTL: Bool { self == .ar }

    /// Matches the on-disk `.lproj` folder the String Catalog compiles to.
    var lprojName: String { rawValue }

    /// The best language for the device's current settings, falling back to English.
    static var deviceDefault: AppLanguage {
        for preferred in Locale.preferredLanguages {
            let code = preferred.lowercased()
            // Script-specific Chinese first (order matters).
            if code.hasPrefix("zh") {
                if code.contains("hant") || code.contains("tw") || code.contains("hk") || code.contains("mo") {
                    return .zhHant
                }
                return .zhHans
            }
            if code.hasPrefix("pt") {
                return code.contains("br") ? .ptBR : .ptPT
            }
            let base = String(code.prefix(2))
            if let match = AppLanguage.allCases.first(where: { $0.rawValue == base }) {
                return match
            }
        }
        return .en
    }
}
