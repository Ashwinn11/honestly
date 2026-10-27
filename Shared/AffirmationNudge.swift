import Foundation
import UserNotifications

/// Two kinds of notification. "Today's affirmation" carries a topic based affirmation on its own
/// schedule. Separately, one "Journal reminder" carrying the writing page's prompt goes out at
/// 8pm on days the page is still unwritten.
enum AffirmationNudge {
    private static let reminderID = "honestly.affirmation.reminder"
    private static let dailyIDPrefix = "honestly.affirmation.daily."
    /// The old scheme queued one echo per line written that morning. Still cleared on every
    /// reschedule, so updating mid-day never leaves those firing alongside the new daily one.
    private static let legacyEchoIDs = (0..<5).map { "honestly.affirmation.echo.\($0)" }
    /// Leave room for the separate journal reminder within iOS's pending-request limit.
    private static let horizonDays = 14
    private static let maximumDailyTimes = 3
    private static let enabledKey = "affirmationNudgeOn"
    private static let reminderLastDayKey = "affirmationReminderLastSentDay"
    private static let reminderPromptKey = "journalReminderPrompt"

    static let defaultMinutes = 9 * 60

    private static var dailyIDs: [String] { (0..<(horizonDays * maximumDailyTimes)).map { dailyIDPrefix + "\($0)" } }
    private static var allIDs: [String] { [reminderID] + dailyIDs + legacyEchoIDs }

    /// Nudges are a premium feature: OFF until a premium user flips the profile toggle (which
    /// writes `enabledKey`), and they go quiet again if the subscription lapses — same
    /// `premiumActive` mirror the shielding extension relies on. An absent key is OFF, matching
    /// the toggle's own default, so onboarding's permission beat never enables anything by itself.
    static var isEnabled: Bool {
        SharedState.premiumActive && SharedState.defaults.bool(forKey: enabledKey)
    }

    /// Legacy single-time preference, used once when migrating older installs.
    static var minutes: Int {
        SharedState.defaults.object(forKey: SharedState.Key.affirmationMinutes) as? Int ?? defaultMinutes
    }

    static var times: [Int] {
        let stored = SharedState.defaults.array(forKey: SharedState.Key.affirmationReminderTimes) as? [Int]
        let raw = stored?.isEmpty == false ? stored! : [minutes]
        return Array(Set(raw.filter { (0..<1440).contains($0) })).sorted().prefix(maximumDailyTimes).map { $0 }
    }
    static var weekdays: [Int] {
        let stored = SharedState.defaults.array(forKey: SharedState.Key.affirmationReminderWeekdays) as? [Int]
        let raw = stored?.isEmpty == false ? stored! : Array(1...7)
        return raw.filter { (1...7).contains($0) }
    }
    /// Used when reminders are enabled in Profile. Requests permission, then lays out the schedule.
    /// Onboarding requests permission separately without enabling reminders.
    /// Scheduling only sticks if iOS is authorized at the moment `add` runs — a later grant never
    /// resurrects dropped requests — which is why grant and schedule live together.
    /// Returns false when iOS won't allow notifications (a fresh denial, or one from earlier —
    /// iOS never re-prompts after that) so callers can surface the Settings hand-off.
    @discardableResult
    static func activate() async -> Bool {
        let granted = await requestPermission()
        guard granted else { return false }
        schedule()
        return true
    }

    /// Permission alone does not enable or schedule Premium reminders.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Re-lays the next `horizonDays` of topic based affirmations. Call when schedule, topics,
    /// language, Premium state, or the reminder toggle changes. Leaves the 8pm journal reminder
    /// alone; it has its own lifecycle.
    static func schedule() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: dailyIDs + legacyEchoIDs)
        guard isEnabled else { return }

        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        let activeDays = Set(weekdays)
        var requestIndex = 0
        for offset in 0..<horizonDays {
            guard let day = cal.date(byAdding: .day, value: offset, to: today),
                  activeDays.contains(cal.component(.weekday, from: day)) else { continue }
            for (timeIndex, time) in times.enumerated() {
                guard let fire = cal.date(bySettingHour: time / 60, minute: time % 60, second: 0, of: day), fire > now else { continue }
                let content = UNMutableNotificationContent()
                content.title = L10n.localized("Today's affirmation")
                let line = Affirmations.dailyLine(on: day, occurrence: timeIndex,
                                                  premium: SharedState.premiumActive)
                guard !line.isEmpty else { continue }
                content.body = Affirmations.display(line)
                content.sound = .default
                let when = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
                center.add(UNNotificationRequest(identifier: dailyIDPrefix + "\(requestIndex)", content: content, trigger: trigger))
                requestIndex += 1
            }
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
    static let reminderHour = 20   // 8pm — gives the whole day to write first
    static func scheduleReminderIfNeeded(ritualDoneToday: Bool) {
        guard isEnabled, !ritualDoneToday else { return }
        let d = SharedState.defaults
        let today = SharedState.dayKey()
        guard d.string(forKey: reminderLastDayKey) != today else { return }   // already handled today
        d.set(today, forKey: reminderLastDayKey)
        addReminder()
    }

    /// The prompt at the top of the writing page, already in the app's language — mirrored by the
    /// app (the 04:00 extension can't read the prompt library) so the reminder can ask it. A
    /// reminder already waiting for tonight is swapped for one with the new prompt.
    static func setReminderPrompt(_ prompt: String?) {
        let d = SharedState.defaults
        guard d.string(forKey: reminderPromptKey) != prompt else { return }
        if let prompt { d.set(prompt, forKey: reminderPromptKey) } else { d.removeObject(forKey: reminderPromptKey) }
        Task {
            let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
            guard pending.contains(where: { $0.identifier == reminderID }) else { return }
            addReminder()
        }
    }

    private static func addReminder() {
        let content = UNMutableNotificationContent()
        // Not SwiftUI here, so `Text(loc:)` doesn't apply — do the String Catalog lookup directly.
        content.title = L10n.localized("Journal reminder")
        let prompt = SharedState.defaults.string(forKey: reminderPromptKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        content.body = prompt?.isEmpty == false
            ? prompt!
            : L10n.localized("Write today's page — a few quiet minutes, just for you.")
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

    static func reset() {
        cancel()
        SharedState.defaults.removeObject(forKey: enabledKey)
        SharedState.defaults.removeObject(forKey: reminderLastDayKey)
        SharedState.defaults.removeObject(forKey: reminderPromptKey)
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
