import Foundation
import UserNotifications

/// One notification a day at the user's chosen time (default 9:00), carrying that day's line from
/// `Affirmations` — the same one Home and the widget show. The rotation is a pure function of the
/// date, so the next `horizonDays` are laid out up front and re-laid from scratch whenever
/// anything feeding them changes. Separately, a single "come write today" reminder goes out at
/// 8pm on days the page is still unwritten.
enum AffirmationNudge {
    private static let reminderID = "honestly.affirmation.reminder"
    private static let dailyIDPrefix = "honestly.affirmation.daily."
    /// The old scheme queued one echo per line written that morning. Still cleared on every
    /// reschedule, so updating mid-day never leaves those firing alongside the new daily one.
    private static let legacyEchoIDs = (0..<5).map { "honestly.affirmation.echo.\($0)" }
    /// iOS keeps at most 64 pending requests per app. A month ahead stays well under that, and
    /// it's re-laid on every foreground, so it only runs dry after a month without opening the app.
    private static let horizonDays = 30
    private static let enabledKey = "affirmationNudgeOn"
    private static let reminderLastDayKey = "affirmationReminderLastSentDay"

    static let defaultMinutes = 9 * 60

    private static var dailyIDs: [String] { (0..<horizonDays).map { dailyIDPrefix + "\($0)" } }
    private static var allIDs: [String] { [reminderID] + dailyIDs + legacyEchoIDs }

    /// Nudges are a premium feature: OFF until a premium user flips the profile toggle (which
    /// writes `enabledKey`), and they go quiet again if the subscription lapses — same
    /// `premiumActive` mirror the shielding extension relies on. An absent key is OFF, matching
    /// the toggle's own default, so onboarding's permission beat never enables anything by itself.
    static var isEnabled: Bool {
        SharedState.premiumActive && SharedState.defaults.bool(forKey: enabledKey)
    }

    /// Minutes after midnight the daily affirmation lands — written by Profile's time picker.
    static var minutes: Int {
        SharedState.defaults.object(forKey: SharedState.Key.affirmationMinutes) as? Int ?? defaultMinutes
    }

    /// The single "nudge became active" path — the onboarding permission beat and the profile
    /// toggle both go through here. Requests permission, then lays out the daily schedule.
    /// Scheduling only sticks if iOS is authorized at the moment `add` runs — a later grant never
    /// resurrects dropped requests — which is why grant and schedule live together.
    /// Returns false when iOS won't allow notifications (a fresh denial, or one from earlier —
    /// iOS never re-prompts after that) so callers can surface the Settings hand-off.
    @discardableResult
    static func activate() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        schedule()
        return true
    }

    /// Re-lays the next `horizonDays` of daily affirmations from scratch. Idempotent — call it
    /// whenever anything feeding it changes: launch/foreground, the rotation, the time, the
    /// language, Premium, the toggle. Leaves the 8pm reminder alone; that has its own lifecycle.
    static func schedule() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: dailyIDs + legacyEchoIDs)
        guard isEnabled else { return }

        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        let title = Affirmations.localized("Today's affirmation")
        for offset in 0..<horizonDays {
            guard let day = cal.date(byAdding: .day, value: offset, to: today),
                  let fire = cal.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day),
                  fire > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = Affirmations.display(Affirmations.line(on: day))
            content.sound = .default
            let when = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            center.add(UNNotificationRequest(identifier: dailyIDPrefix + "\(offset)", content: content, trigger: trigger))
        }
    }

    /// Call once today's page is written — the 8pm "come write" reminder no longer applies.
    static func ritualWritten() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID])
    }

    /// Call once a day from `ActivityMonitorExtension.intervalDidStart` (04:00) — runs even if the
    /// app itself is never opened, so a day with zero app-opens still gets a reminder. Ritual can
    /// never be done yet at 04:00, so this schedules for a fixed later time of day, cancelled by
    /// `ritualWritten` if the user does end up writing before then. Fires at most once per day.
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
