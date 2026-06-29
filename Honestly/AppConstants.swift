import Foundation
import FamilyControls
import BackgroundTasks

struct AppConstants {
    nonisolated static let appGroupIdentifier = "group.morning-journal.app"

    static let bgNotifTaskID = "com.morning-journal.app.notif-refresh"

    static let morningStartHour = 4
    static let morningEndHour = 23

    static let premiumEntitlementID = "premium"

    static let keyTodayCompleted = "todayCompleted"
    static let keyLastCompletionDate = "lastCompletionDate"
    static let keySelection = "familyActivitySelection"
    static let keyIsPremium = "isPremiumSubscriber"
    static let keyIsBlocking = "isCurrentlyBlocking"
    static let keyAppLanguage = "app_language"
    static let keyCloudSyncEnabled = "isCloudSyncEnabled"
    static let keyBlockingEnabled = "blockingEnabled"
    static let keyHasSeenPaywall = "hasSeenPaywall"
    static let keyHasCompletedOnboarding = "hasCompletedOnboarding"
    static let keyUserOutcome = "userOutcome"
    static let keyUserName = "userName"
    static let keyScrollMinutes = "scrollMinutes"
    static let keySproutCount = "sproutCollectionCount"

    static let plantStageThresholds = [0, 10, 30, 90, 180]

    static func stageForCount(_ count: Int) -> Int {
        var stage = 0
        for (i, threshold) in plantStageThresholds.enumerated() where count >= threshold {
            stage = i
        }
        return stage
    }

    static let widgetKeyMood = "widget.mood"
    static let widgetKeyGratitude = "widget.gratitude"
    static let widgetKeyJournal = "widget.journal"
    static let widgetKeyDate = "widget.date"

    static let activityNameMorningBlock = "MorningJournal.MorningBlock"
    static let storeNameMorningBlock = "morningBlock"

    static func isJournalCompleted(in defaults: UserDefaults?) -> Bool {
        let completed = defaults?.bool(forKey: keyTodayCompleted) ?? false
        guard completed else { return false }
        if let lastDate = defaults?.object(forKey: keyLastCompletionDate) as? Date {
            return Calendar.current.isDateInToday(lastDate)
        }
        return false
    }

    static func isSelectionValid(_ selection: FamilyActivitySelection, isPremium: Bool) -> Bool {
        return isPremium
    }

    static func isWithinSchedule(hour: Int) -> Bool {
        return hour >= morningStartHour && hour <= morningEndHour
    }

    static func scheduleBackgroundNotifRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: bgNotifTaskID)
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 8
        components.minute = 50
        if let fireDate = Calendar.current.date(from: components) {
            let target = fireDate < Date()
                ? Calendar.current.date(byAdding: .day, value: 1, to: fireDate)!
                : fireDate
            request.earliestBeginDate = target
        }
        try? BGTaskScheduler.shared.submit(request)
    }
}
