import Foundation

/// Privacy / Terms copy — mirrors what's published on the Honestly landing page
/// (hosting/src/config/apps.ts), last updated May 30, 2026.
enum LegalDoc: String, Identifiable {
    case privacy
    case terms

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: return "Privacy Policy"
        case .terms:   return "Terms of Service"
        }
    }

    var lastUpdated: String { "May 30, 2026" }

    var body: String {
        switch self {
        case .privacy:
            return """
            Data collection:
            - We collect no personal information
            - We do not use third-party analytics
            - We do not track your activity across other apps
            - Journal entries are stored securely on-device using Apple's protected local storage

            Data retention and deletion:
            - Journal data remains on-device unless you delete it
            - You can delete all local data from Settings inside the app

            Contact:
            - Email: ashwinnanbazhagan@gmail.com
            """
        case .terms:
            return """
            Subscription terms:
            - Premium features are offered as auto-renewing subscriptions
            - Payment is charged to your Apple ID account at confirmation
            - Subscription renews automatically unless canceled at least 24 hours before the period ends
            - You can manage or cancel subscriptions in Apple ID Subscriptions settings
            - Restore Purchases is available in the app

            Usage:
            - You are responsible for how you configure app blocking selections
            - The app depends on Screen Time authorization and Apple platform behavior

            Disclaimer:
            - Service is provided as-is without guarantees of uninterrupted availability

            Contact:
            - Email: ashwinnanbazhagan@gmail.com
            """
        }
    }
}
