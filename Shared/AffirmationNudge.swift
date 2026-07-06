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

    /// Nudges are a premium feature: OFF until a premium user flips the profile toggle (which
    /// writes `enabledKey`), and they go quiet again if the subscription lapses — same
    /// `premiumActive` mirror the shielding extension relies on. An absent key is OFF, matching
    /// the toggle's own default, so onboarding's permission beat never enables anything by itself.
    static var isEnabled: Bool {
        SharedState.premiumActive && SharedState.defaults.bool(forKey: enabledKey)
    }

    /// The single "nudge became active" path — the onboarding permission beat and the profile
    /// toggle both go through here. Requests permission, then recovers today's echoes if the
    /// ritual is already written (either flow), so enabling late in the day isn't silent until
    /// tomorrow. Scheduling only sticks if iOS is authorized at the moment `add` runs — a later
    /// grant never resurrects dropped requests — which is why grant and schedule live together.
    /// Returns false when iOS won't allow notifications (a fresh denial, or one from earlier —
    /// iOS never re-prompts after that) so callers can surface the Settings hand-off.
    @discardableResult
    static func activate() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        if SharedState.ritualCompleted() { scheduleForToday() }
        return true
    }

    /// Call right after a ritual (or the onboarding demo) finishes for the day. Replaces whatever
    /// was previously scheduled for today: one echo per non-empty line of today's affirmations, or
    /// — if there are none — the generic reminder, so there's always exactly one outcome per day.
    /// Reads `SharedState.todayAffirmations` (synced by `JournalStore` on every mutation) rather
    /// than taking the lines as a parameter, so every caller schedules from the same source of truth.
    static func scheduleForToday() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: allIDs)
        guard isEnabled else { return }

        let lines = SharedState.todayAffirmations
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
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
