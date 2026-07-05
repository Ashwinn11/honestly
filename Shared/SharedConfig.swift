import Foundation

enum AppConfig {
    static let bundleID            = "com.morning-journal.app"
    static let appGroupID          = "group.morning-journal.app"
    static let iCloudContainerID   = "iCloud.com.morning-journal.app"
    static let appStoreID          = "6759817879"   // Honestly on the App Store — used for the review deep link

    static let activityMonitorID   = "com.morning-journal.app.activity-monitor"
    static let shieldConfigID      = "com.morning-journal.app.ShieldConfiguration"
    static let shieldActionID      = "com.morning-journal.app.ShieldAction"

    // RevenueCat — replace with the real public SDK key before shipping.
    static let revenueCatAPIKey    = "test_dKMMvIxKaUMZklmdVFugqpnknFW"
    static let entitlementID       = "premium"
    static let lifetimePackageID   = "$rc_lifetime"
    static let monthlyPackageID    = "$rc_monthly"

    static let morningScheduleName = "morning.block.window"

    static let blockStartHour   = 4
    static let blockStartMinute = 0
    static let blockEndHour     = 23
    static let blockEndMinute   = 59
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
        static let onboardingGoal     = "onboarding.goal"           // primary stated goal (OnbGoal key)
        static let scrollMinutes      = "onboarding.scrollMinutes"  // self-reported morning scroll minutes
        static let appsPhrase         = "onboarding.appsPhrase"     // display phrase for the apps they picked, e.g. "Instagram & TikTok"
        static let demoMood           = "onboarding.demoMood"       // mood face they tapped during the onboarding demo
        static let demoLine           = "onboarding.demoLine"       // the line they wrote during the onboarding demo
        static let demoAffirmation    = "onboarding.demoAffirmation" // the affirmation they wrote during the onboarding demo
        static let premiumActive      = "premium.active"             // mirrors PremiumManager.isPremium for the background extension
    }

    // MARK: Day key helpers

    static func dayKey(for date: Date = Date()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func entryID(for date: Date = Date()) -> String { "journal-\(dayKey(for: date))" }

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

    // MARK: Onboarding answers (drive the personalized plan, paywall, and weekly goal)

    static var weeklyGoal: Int {
        get { let v = defaults.integer(forKey: Key.weeklyGoal); return v == 0 ? 5 : v }
        set { defaults.set(newValue, forKey: Key.weeklyGoal) }
    }

    static var onboardingGoal: String {
        get { defaults.string(forKey: Key.onboardingGoal) ?? "" }
        set { defaults.set(newValue, forKey: Key.onboardingGoal) }
    }

    static var scrollMinutes: Int {
        get { defaults.integer(forKey: Key.scrollMinutes) }
        set { defaults.set(newValue, forKey: Key.scrollMinutes) }
    }

    static var appsPhrase: String {
        get { defaults.string(forKey: Key.appsPhrase) ?? "" }
        set { defaults.set(newValue, forKey: Key.appsPhrase) }
    }

    // MARK: Onboarding demo (the "try it now" morning page — reused to preview what unlocking keeps)

    static var demoMood: Int {
        get { defaults.object(forKey: Key.demoMood) as? Int ?? -1 }
        set { defaults.set(newValue, forKey: Key.demoMood) }
    }

    static var demoLine: String {
        get { defaults.string(forKey: Key.demoLine) ?? "" }
        set { defaults.set(newValue, forKey: Key.demoLine) }
    }

    static var demoAffirmation: String {
        get { defaults.string(forKey: Key.demoAffirmation) ?? "" }
        set { defaults.set(newValue, forKey: Key.demoAffirmation) }
    }

    // MARK: Premium (mirrored so the background DeviceActivityMonitor extension, which has no
    // RevenueCat access, can bail out of re-shielding once a subscription lapses)

    static var premiumActive: Bool {
        get { defaults.bool(forKey: Key.premiumActive) }
        set { defaults.set(newValue, forKey: Key.premiumActive) }
    }
}
