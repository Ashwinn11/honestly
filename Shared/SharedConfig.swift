import Foundation

enum AppConfig {
    static let appGroupID          = "group.morning-journal.app"
    static let iCloudContainerID   = "iCloud.com.morning-journal.app"
    static let appStoreID          = "6759817879"   // Honestly on the App Store — used for the review deep link

    // RevenueCat — replace with the real public SDK key before shipping.
    static let revenueCatAPIKey    = "test_dKMMvIxKaUMZklmdVFugqpnknFW" // "appl_zRRSBwyTqHGTNBJtwyKyrDifAdI"
    static let entitlementID       = "premium"
    static let lifetimePackageID   = "$rc_lifetime"
    static let monthlyPackageID    = "$rc_monthly"

    static let morningScheduleName = "morning.block.window"

    static let blockStartHour   = 4
    static let blockStartMinute = 0
    static let blockEndHour     = 23
    static let blockEndMinute   = 59

    /// True when `date` falls inside the daily block window above.
    static func isWithinBlockWindow(_ date: Date = Date()) -> Bool {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let mins = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return mins >= blockStartHour * 60 + blockStartMinute
            && mins <= blockEndHour * 60 + blockEndMinute
    }
}

/// App-group–backed state shared between the app and its extensions.
/// The shield/monitor read this to decide whether the ritual is done and how to render.
enum SharedState {
    static let defaults = UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard

    enum Key {
        static let onboardingComplete = "onboarding.complete"
        static let blockingEnabled    = "blocking.enabled"
        static let selectionData      = "blocking.selection"
        static let lastRitualDay      = "ritual.lastCompletedDay"   // "yyyy-MM-dd"
        static let todayMood          = "ritual.todayMood"          // mood key for shield tint
        static let language           = "app.language"              // "en" | "es"
        static let hasEverBlocked     = "blocking.hasEverConfigured"
        static let streak             = "ritual.streak"
        static let weeklyGoal         = "onboarding.weeklyGoal"     // mornings/week the user committed to
        static let premiumActive      = "premium.active"             // mirrors PremiumManager.isPremium for the background extension
        static let customAffirmations = "affirmations.custom"        // Saved independently of the selected rotation.
        static let deletedAffirmations = "affirmations.deleted"
        static let affirmationFavorites = "affirmations.favorites"
        static let affirmationHistory = "affirmations.history"
        static let affirmationTopics = "affirmations.topics"
        static let affirmationFeedFocuses = "affirmations.feedFocuses" // Legacy shared-topic key.
        static let affirmationReminderTimes = "affirmations.reminderTimes"
        static let affirmationReminderWeekdays = "affirmations.reminderWeekdays"
        static let affirmationReminderFocuses = "affirmations.reminderFocuses"
        static let affirmationWidgetFocuses = "affirmations.widgetFocuses"
        static let affirmationWidgetTheme = "affirmations.widgetTheme"
        static let affirmationWidgetBackgroundColor = "affirmations.widgetBackgroundColor"
        static let affirmationWidgetTextColor = "affirmations.widgetTextColor"
        static let affirmationWidgetFont = "affirmations.widgetFont"
        static let affirmationMinutes = "affirmations.notifyMinutes" // Legacy single-time reminder value, retained for migration.
    }

    // MARK: Day key helpers

    static func dayKey(for date: Date = Date()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: Ritual completion

    static var lastRitualDay: String? {
        get { defaults.string(forKey: Key.lastRitualDay) }
        set { defaults.set(newValue, forKey: Key.lastRitualDay) }
    }

    static func ritualCompleted(on date: Date = Date()) -> Bool {
        lastRitualDay == dayKey(for: date)
    }

    static func markRitualComplete(mood: String, on date: Date = Date()) {
        lastRitualDay = dayKey(for: date)
        defaults.set(mood, forKey: Key.todayMood)
    }

    // MARK: Flags

    static var onboardingComplete: Bool {
        get { defaults.bool(forKey: Key.onboardingComplete) }
        set { defaults.set(newValue, forKey: Key.onboardingComplete) }
    }

    static var blockingEnabled: Bool {
        get { defaults.bool(forKey: Key.blockingEnabled) }
        set { defaults.set(newValue, forKey: Key.blockingEnabled) }
    }

    static var hasEverConfiguredBlocking: Bool {
        get { defaults.bool(forKey: Key.hasEverBlocked) }
        set { defaults.set(newValue, forKey: Key.hasEverBlocked) }
    }

    static var todayMoodKey: String? {
        get { defaults.string(forKey: Key.todayMood) }
        set { defaults.set(newValue, forKey: Key.todayMood) }
    }

    static var language: String {
        get { defaults.string(forKey: Key.language) ?? "en" }
        set { defaults.set(newValue, forKey: Key.language) }
    }

    static var streak: Int {
        get { defaults.integer(forKey: Key.streak) }
        set { defaults.set(newValue, forKey: Key.streak) }
    }

    // MARK: Onboarding — weekly goal (drives the streak-goal progress ring on Home)

    static var weeklyGoal: Int {
        // 5 was the previous baked-in goal; no UI allows choosing a custom value, so migrate it.
        get {
            let value = defaults.integer(forKey: Key.weeklyGoal)
            return value == 0 || value == 5 ? 7 : value
        }
        set { defaults.set(newValue, forKey: Key.weeklyGoal) }
    }

    /// The widget's look until someone picks one — and always for its "get started" and "unlock"
    /// states, which no custom colours apply to. Fresh and green rather than plain paper.
    static let defaultWidgetTheme = PageTheme.garden.rawValue

    /// Last editor theme, mirrored so affirmation widgets can share the journal's look.
    static var affirmationWidgetTheme: String {
        get { defaults.string(forKey: Key.affirmationWidgetTheme) ?? defaultWidgetTheme }
        set { defaults.set(newValue, forKey: Key.affirmationWidgetTheme) }
    }

    static var affirmationWidgetBackgroundColor: String? {
        get {
            guard let value = defaults.string(forKey: Key.affirmationWidgetBackgroundColor), !value.isEmpty else { return nil }
            return value
        }
        set {
            if let newValue { defaults.set(newValue, forKey: Key.affirmationWidgetBackgroundColor) }
            else { defaults.removeObject(forKey: Key.affirmationWidgetBackgroundColor) }
        }
    }

    static var affirmationWidgetTextColor: String {
        get { defaults.string(forKey: Key.affirmationWidgetTextColor) ?? "33261A" }
        set { defaults.set(newValue, forKey: Key.affirmationWidgetTextColor) }
    }

    static var affirmationWidgetFont: String {
        get { defaults.string(forKey: Key.affirmationWidgetFont) ?? "Manrope" }
        set { defaults.set(newValue, forKey: Key.affirmationWidgetFont) }
    }

    // MARK: Premium (mirrored so the background DeviceActivityMonitor extension, which has no
    // RevenueCat access, can bail out of re-shielding once a subscription lapses)

    static var premiumExpiration: Date? {
        get { defaults.object(forKey: "premium.expiration") as? Date }
        set { defaults.set(newValue, forKey: "premium.expiration") }
    }

    static var premiumLifetime: Bool {
        get { defaults.bool(forKey: "premium.lifetime") }
        set { defaults.set(newValue, forKey: "premium.lifetime") }
    }

    /// Set once Premium is bought or restored on this install. RevenueCat also finds purchases
    /// on the Apple ID by itself (a reinstall, a new phone); those don't unlock anything until
    /// the person taps Restore purchases. The app group's defaults go with the app on delete, so
    /// a fresh install always starts unclaimed.
    static var premiumClaimed: Bool {
        get { defaults.bool(forKey: "premium.claimed") }
        set { defaults.set(newValue, forKey: "premium.claimed") }
    }

    static var premiumActive: Bool {
        get {
            guard defaults.bool(forKey: Key.premiumActive) else { return false }
            return premiumExpiration.map { $0 > Date() } ?? true
        }
        set { defaults.set(newValue, forKey: Key.premiumActive) }
    }

}
