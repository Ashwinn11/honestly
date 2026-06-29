import Foundation

/// Privacy / Terms copy — mirrors what's published on the Honestly landing page
/// (hosting/src/config/apps.ts), last updated May 30, 2026.
enum LegalDoc: String, Identifiable {
    case privacy
    case terms

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: return L("Privacy Policy")
        case .terms:   return L("Terms of Service")
        }
    }

    var lastUpdated: String { "May 30, 2026" }

    /// Built from per-line localized pieces so each line is its own catalog key.
    /// The email line is left verbatim — it's an address, not translatable copy.
    var body: String {
        switch self {
        case .privacy:
            return [
                L("Data collection:"),
                L("- We collect no personal information"),
                L("- We do not use third-party analytics"),
                L("- We do not track your activity across other apps"),
                L("- Journal entries are stored securely on-device using Apple's protected local storage"),
                "",
                L("Data retention and deletion:"),
                L("- Journal data remains on-device unless you delete it"),
                L("- You can delete all local data from Settings inside the app"),
                "",
                L("Contact:"),
                "- Email: ashwinnanbazhagan@gmail.com",
            ].joined(separator: "\n")
        case .terms:
            return [
                L("Subscription terms:"),
                L("- Premium features are offered as auto-renewing subscriptions"),
                L("- Payment is charged to your Apple ID account at confirmation"),
                L("- Subscription renews automatically unless canceled at least 24 hours before the period ends"),
                L("- You can manage or cancel subscriptions in Apple ID Subscriptions settings"),
                L("- Restore Purchases is available in the app"),
                "",
                L("Usage:"),
                L("- You are responsible for how you configure app blocking selections"),
                L("- The app depends on Screen Time authorization and Apple platform behavior"),
                "",
                L("Disclaimer:"),
                L("- Service is provided as-is without guarantees of uninterrupted availability"),
                "",
                L("Contact:"),
                "- Email: ashwinnanbazhagan@gmail.com",
            ].joined(separator: "\n")
        }
    }
}
