import Foundation

enum AppConfig {
    static let appGroupID          = "group.morning-journal.app"
    static let iCloudContainerID   = "iCloud.com.morning-journal.app"
    static let appStoreID          = "6759817879"   // Honestly on the App Store — used for the review deep link

    // RevenueCat — replace with the real public SDK key before shipping.
    static let revenueCatAPIKey    = "appl_zRRSBwyTqHGTNBJtwyKyrDifAdI"
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
        static let onboardingGoal     = "onboarding.goal"           // primary stated goal (OnbGoal key)
        static let scrollMinutes      = "onboarding.scrollMinutes"  // self-reported morning scroll minutes
        static let demoMood           = "onboarding.demoMood"       // mood face they tapped during the onboarding demo
        static let demoLine           = "onboarding.demoLine"       // the line they wrote during the onboarding demo
        static let demoAffirmation    = "onboarding.demoAffirmation" // the affirmation they wrote during the onboarding demo
        static let premiumActive      = "premium.active"             // mirrors PremiumManager.isPremium for the background extension
        static let todayAffirmations  = "ritual.todayAffirmations"   // [String] — today's written affirmations, in order (widget data source)
        static let todayAffirmationsSetAt = "ritual.todayAffirmationsSetAt"  // when they were last saved (widget rotation start time)
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

    // MARK: Widget data (BigWinsWidget reads these directly — no SwiftData access across processes)

    static var todayAffirmations: [String] {
        get { defaults.stringArray(forKey: Key.todayAffirmations) ?? [] }
        set { defaults.set(newValue, forKey: Key.todayAffirmations) }
    }

    static var todayAffirmationsSetAt: Date? {
        get {
            let t = defaults.double(forKey: Key.todayAffirmationsSetAt)
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set { defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: Key.todayAffirmationsSetAt) }
    }
}
