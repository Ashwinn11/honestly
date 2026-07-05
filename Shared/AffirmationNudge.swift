import Foundation
import UserNotifications

/// One notification per affirmation actually written today, each quoting that specific line —
/// so writing 1 affirmation sends 1 notification, writing 5 sends 5. If today has none (ritual
/// skipped, or completed with the affirmation field left blank), sends a single generic
/// "come write today" reminder instead — fired at most once per day.
enum AffirmationNudge {
    private static let reminderID = "honestly.affirmation.reminder"
    private static let echoIDPrefix = "honestly.affirmation.echo."
    private static let maxEchoes = 5   // matches RitualView's 5 affirmation slots
    private static let enabledKey = "affirmationNudgeOn"
    private static let reminderLastDayKey = "affirmationReminderLastSentDay"

    private static var allIDs: [String] { [reminderID] + (0..<maxEchoes).map { echoIDPrefix + "\($0)" } }

    /// Fixed cadence, no randomness: slot 0 fires 2 hours out, slot 1 at 4 hours, slot 2 at 6
    /// hours, and so on. Which affirmation lands in which slot doesn't matter, so a predictable,
    /// evenly spaced schedule means writing just one doesn't end up waiting longer than writing
    /// several — it's always the same +2h first step either way.
    private static let intervalHours = 2.0
    private static func delay(forSlot slot: Int) -> TimeInterval {
        Double(slot + 1) * intervalHours * 3600
    }

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
            sendImmediateReminder(center: center)
        } else {
            for (i, line) in lines.prefix(maxEchoes).enumerated() {
                let content = UNMutableNotificationContent()
                // Not SwiftUI here, so `Text(loc:)` doesn't apply — do the String Catalog lookup directly.
                content.title = String(localized: "Today's affirmation")
                content.body = line   // the user's own words — never translated/rewritten
                content.sound = .default
                let seconds = delay(forSlot: i)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
                center.add(UNNotificationRequest(identifier: echoIDPrefix + "\(i)", content: content, trigger: trigger))
            }
        }
    }

    /// Call once a day from `ActivityMonitorExtension.intervalDidStart` (04:00) — runs even if the
    /// app itself is never opened, so a day with zero app-opens still gets a reminder. Ritual can
    /// never be done yet at 04:00, so unlike `scheduleForToday`'s relative "+2h" delay, this
    /// schedules for a fixed later time of day instead — cancelled automatically by
    /// `scheduleForToday` if the user does end up writing before then. Fires at most once per day.
    private static let reminderHour = 20   // 8pm — gives the whole day to write first
    static func scheduleReminderIfNeeded(ritualDoneToday: Bool) {
        guard isEnabled, !ritualDoneToday else { return }
        let d = SharedState.defaults
        let today = SharedState.dayKey()
        guard d.string(forKey: reminderLastDayKey) != today else { return }   // already handled today
        d.set(today, forKey: reminderLastDayKey)

        let content = UNMutableNotificationContent()
        content.title = "Honestly"   // brand name — not localized
        // Not SwiftUI here, so `Text(loc:)` doesn't apply — do the String Catalog lookup directly.
        content.body = String(localized: "Write today's page — a few quiet minutes, just for you.")
        content.sound = .default

        var when = DateComponents()
        when.hour = reminderHour
        when.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger))
    }

    /// Used only by `scheduleForToday`'s empty-lines case — the ritual was engaged with today (so
    /// a relative delay from "now" makes sense here, unlike the fixed-time version above).
    private static func sendImmediateReminder(center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = "Honestly"   // brand name — not localized
        // Not SwiftUI here, so `Text(loc:)` doesn't apply — do the String Catalog lookup directly.
        content.body = String(localized: "Write today's page — a few quiet minutes, just for you.")
        content.sound = .default
        let seconds = delay(forSlot: 0)   // a lone reminder is always the first (and only) slot
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
