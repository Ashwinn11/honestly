import Foundation

/// Cross-target constants and shared state. Pure Foundation so it compiles cleanly
/// into the app **and** every extension (DeviceActivity monitor + both shields).
enum AppConfig {
    static let bundleID            = "com.morning-journal.app"
    static let appGroupID          = "group.morning-journal.app"
    static let iCloudContainerID   = "iCloud.com.morning-journal.app"

    static let activityMonitorID   = "com.morning-journal.app.activity-monitor"
    static let shieldConfigID      = "com.morning-journal.app.ShieldConfiguration"
    static let shieldActionID      = "com.morning-journal.app.ShieldAction"

    // RevenueCat — replace with the real public SDK key before shipping.
    static let revenueCatAPIKey    = "test_dKMMvIxKaUMZklmdVFugqpnknFW"
    static let entitlementID       = "premium"
    static let lifetimePackageID   = "$rc_lifetime"
    static let monthlyPackageID    = "$rc_monthly"

    // DeviceActivity schedule identity (built into DeviceActivityName in app + monitor).
    static let morningScheduleName = "morning.block.window"

    /// The block opens at 04:00 and lifts automatically at 23:59.
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

    /// Mornings-per-week the user committed to in onboarding. Defaults to 5 as a sane fallback.
    static var weeklyGoal: Int {
        get { let v = defaults.integer(forKey: Key.weeklyGoal); return v == 0 ? 5 : v }
        set { defaults.set(newValue, forKey: Key.weeklyGoal) }
    }

    /// The primary goal chosen in onboarding (an `OnbGoal` raw key); read by the paywall.
    static var onboardingGoal: String {
        get { defaults.string(forKey: Key.onboardingGoal) ?? "" }
        set { defaults.set(newValue, forKey: Key.onboardingGoal) }
    }

    /// Self-reported minutes spent scrolling first thing — the honest input to reclaimed-time.
    static var scrollMinutes: Int {
        get { defaults.integer(forKey: Key.scrollMinutes) }
        set { defaults.set(newValue, forKey: Key.scrollMinutes) }
    }
}
