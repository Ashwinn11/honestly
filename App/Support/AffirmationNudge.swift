import Foundation
import UserNotifications

/// One notification per affirmation actually written today, each quoting that specific line at
/// its own random delay — so writing 1 affirmation sends 1 notification, writing 5 sends 5. If
/// today has none (ritual skipped, or completed with the affirmation field left blank), sends a
/// single generic "come write today" reminder instead — fired at most once per day.
enum AffirmationNudge {
    private static let reminderID = "honestly.affirmation.reminder"
    private static let echoIDPrefix = "honestly.affirmation.echo."
    private static let maxEchoes = 5   // matches RitualView's 5 affirmation slots
    private static let enabledKey = "affirmationNudgeOn"
    private static let reminderLastDayKey = "affirmationReminderLastSentDay"

    private static var allIDs: [String] { [reminderID] + (0..<maxEchoes).map { echoIDPrefix + "\($0)" } }

    static var isEnabled: Bool {
        let d = SharedState.defaults
        return d.object(forKey: enabledKey) == nil ? true : d.bool(forKey: enabledKey)
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Call right after a ritual (or the onboarding demo) finishes for the day. Replaces whatever
    /// was previously scheduled for today: one echo per non-empty line in `todaysAffirmations`, or
    /// — if that's empty — the generic reminder, so there's always exactly one outcome per day.
    static func scheduleForToday(_ todaysAffirmations: [String]) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: allIDs)
        guard isEnabled else { return }

        let lines = todaysAffirmations.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if lines.isEmpty {
            sendReminder(center: center, markDay: false)
        } else {
            for (i, line) in lines.prefix(maxEchoes).enumerated() {
                let content = UNMutableNotificationContent()
                // Not SwiftUI here, so `Text(loc:)` doesn't apply — do the String Catalog lookup directly.
                content.title = String(localized: "Today's affirmation")
                content.body = line   // the user's own words — never translated/rewritten
                content.sound = .default
                let seconds = TimeInterval(Int.random(in: 2 * 3600...10 * 3600))   // 2–10 hours out
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
                center.add(UNNotificationRequest(identifier: echoIDPrefix + "\(i)", content: content, trigger: trigger))
            }
        }
    }

    /// Call on app launch/foreground. Covers the case `scheduleForToday` never runs at all because
    /// the user hasn't opened the ritual today — fires the generic reminder once for the day, and
    /// only once, no matter how many times the app is opened without writing.
    static func scheduleReminderIfNeeded(ritualDoneToday: Bool) {
        guard isEnabled, !ritualDoneToday else { return }
        let d = SharedState.defaults
        let today = SharedState.dayKey()
        guard d.string(forKey: reminderLastDayKey) != today else { return }   // already handled today
        sendReminder(center: UNUserNotificationCenter.current(), markDay: true)
    }

    private static func sendReminder(center: UNUserNotificationCenter, markDay: Bool) {
        if markDay {
            SharedState.defaults.set(SharedState.dayKey(), forKey: reminderLastDayKey)
        }
        let content = UNMutableNotificationContent()
        content.title = "Honestly"   // brand name — not localized
        // Not SwiftUI here, so `Text(loc:)` doesn't apply — do the String Catalog lookup directly.
        content.body = String(localized: "Write today's page — a few quiet minutes, just for you.")
        content.sound = .default
        let seconds = TimeInterval(Int.random(in: 2 * 3600...10 * 3600))   // 2–10 hours out
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        center.add(UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: allIDs)
    }

    /// Without a delegate, iOS silently drops local notifications while the app is in the
    /// foreground — no banner, no sound. Set as `UNUserNotificationCenter.current().delegate` at
    /// launch so the nudge actually shows even if the app happens to be open when it fires.
    final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
        static let shared = ForegroundPresenter()
        func userNotificationCenter(_ center: UNUserNotificationCenter,
                                     willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
            [.banner, .sound, .list]
        }
    }
}
