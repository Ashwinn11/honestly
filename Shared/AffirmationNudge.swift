import Foundation
import UserNotifications

/// Two kinds of notification. "Today's affirmation" carries a topic based affirmation on its own
/// schedule. Separately, one "Journal reminder" carrying the day's writing prompt goes out at the
/// time the user picked (8am unless they chose another) on days the page is still unwritten.
enum AffirmationNudge {
    private static let legacyReminderID = "honestly.affirmation.reminder"
    private static let reminderIDPrefix = "honestly.journal.reminder."
    private static let dailyIDPrefix = "honestly.affirmation.daily."
    /// The old scheme queued one echo per line written that morning. Still cleared on every
    /// reschedule, so updating mid-day never leaves those firing alongside the new daily one.
    private static let legacyEchoIDs = (0..<5).map { "honestly.affirmation.echo.\($0)" }
    /// Leave room for the separate journal reminder within iOS's pending-request limit.
    private static let horizonDays = 14
    /// A rolling journal queue means the free reminder works without a Screen Time callback.
    /// 42 affirmation requests + 14 journal requests + 5 legacy IDs stay below iOS's 64-request cap.
    private static let journalReminderHorizonDays = 14
    private static let maximumDailyTimes = 3
    private static let enabledKey = "affirmationNudgeOn"
    private static let reminderLastDayKey = "affirmationReminderLastSentDay" // legacy; cleared on reset
    private static let reminderPromptsKey = "journalReminderPrompts"   // day key → that day's prompt
    private static let journalMinutesKey = "journalReminderMinutes"    // minutes after midnight

    static let defaultMinutes = 9 * 60

    private static var dailyIDs: [String] { (0..<(horizonDays * maximumDailyTimes)).map { dailyIDPrefix + "\($0)" } }
    private static var allIDs: [String] { [legacyReminderID] + journalReminderIDs + dailyIDs + legacyEchoIDs }

    private static func journalReminderID(for date: Date) -> String {
        reminderIDPrefix + SharedState.dayKey(for: date)
    }

    /// Include yesterday to clean up a missed legacy request and all dates in the rolling window.
    private static var journalReminderIDs: [String] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (-1...journalReminderHorizonDays).compactMap {
            calendar.date(byAdding: .day, value: $0, to: today)
        }.map { journalReminderID(for: $0) }
    }

    /// Reminders are free. They're on once someone allows notifications in onboarding (see
    /// `enable`) or flips the toggle in Affirmation delivery; an absent key is OFF.
    static var isEnabled: Bool {
        SharedState.defaults.bool(forKey: enabledKey)
    }

    /// Turns reminders on and lays out their schedule — onboarding calls this the moment
    /// notifications are allowed, so the permission it asked for actually brings reminders.
    static func enable() {
        SharedState.defaults.set(true, forKey: enabledKey)
        schedule()
        scheduleReminderIfNeeded(ritualDoneToday: SharedState.ritualCompleted())
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
    /// Onboarding asks for permission itself and then calls `enable`.
    /// Scheduling only sticks if iOS is authorized at the moment `add` runs — a later grant never
    /// resurrects dropped requests — which is why grant and schedule live together.
    /// Returns false when iOS won't allow notifications (a fresh denial, or one from earlier —
    /// iOS never re-prompts after that) so callers can surface the Settings hand-off.
    @discardableResult
    static func activate() async -> Bool {
        let granted = await requestPermission()
        guard granted else { return false }
        schedule()
        scheduleReminderIfNeeded(ritualDoneToday: SharedState.ritualCompleted())
        return true
    }

    /// Asks iOS for permission only; `enable` turns the reminders on.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Re-lays the next `horizonDays` of topic based affirmations. Call when schedule, topics,
    /// language, Premium state, or the reminder toggle changes. Leaves the journal reminder alone;
    /// it has its own lifecycle.
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

    /// Call once today's page is written — keep future reminders queued, but remove today's.
    static func ritualWritten() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [legacyReminderID, journalReminderID(for: Date())])
    }

    /// Maintains a rolling two-week queue. Called from app launch/resume, reminder enablement, and
    /// the 04:00 DeviceActivity callback when available. It does not depend on Screen Time access.
    static let defaultJournalMinutes = 8 * 60   // 8am — the morning journal reminder

    /// When the journal reminder goes out, in minutes after midnight — picked in onboarding or in
    /// Notification reminders. Stored in the app group so the 04:00 extension queues the same time.
    static var journalReminderMinutes: Int {
        let stored = SharedState.defaults.object(forKey: journalMinutesKey) as? Int
        return stored.flatMap { (0..<1440).contains($0) ? $0 : nil } ?? defaultJournalMinutes
    }

    static func setJournalReminderMinutes(_ minutes: Int) {
        SharedState.defaults.set(minutes, forKey: journalMinutesKey)
        scheduleJournalReminders(ritualDoneToday: SharedState.ritualCompleted())
    }

    static func scheduleReminderIfNeeded(ritualDoneToday: Bool) {
        scheduleJournalReminders(ritualDoneToday: ritualDoneToday)
    }

    static func scheduleJournalReminders(ritualDoneToday: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [legacyReminderID] + journalReminderIDs)
        guard isEnabled else { return }

        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let todayKey = SharedState.dayKey(for: today)
        for offset in 0..<journalReminderHorizonDays {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            if SharedState.dayKey(for: date) == todayKey && ritualDoneToday { continue }
            addReminder(for: date, now: now)
        }
    }

    /// Each coming day's writing-page prompt, already in the app's language — mirrored by the
    /// app (the 04:00 extension can't read the prompt library) so each morning's reminder asks
    /// that day's prompt. If today's changed, a reminder already waiting for tonight is swapped.
    static func setReminderPrompts(_ byDay: [String: String]) {
        let d = SharedState.defaults
        let old = d.dictionary(forKey: reminderPromptsKey) as? [String: String]
        guard old != byDay else { return }
        d.set(byDay, forKey: reminderPromptsKey)
        scheduleJournalReminders(ritualDoneToday: SharedState.ritualCompleted())
    }

    private static func addReminder(for date: Date, now: Date) {
        let calendar = Calendar.current
        let minutes = journalReminderMinutes
        guard let fireDate = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: date),
              fireDate > now else { return }

        let content = journalReminderContent(for: date)
        let when = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: journalReminderID(for: date), content: content, trigger: trigger))
    }

    private static func journalReminderContent(for date: Date) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        // Not SwiftUI here, so `Text(loc:)` doesn't apply — do the String Catalog lookup directly.
        content.title = L10n.localized("Journal reminder")
        let prompts = SharedState.defaults.dictionary(forKey: reminderPromptsKey) as? [String: String]
        let prompt = prompts?[SharedState.dayKey(for: date)]?.trimmingCharacters(in: .whitespacesAndNewlines)
        content.body = prompt?.isEmpty == false
            ? prompt!
            : L10n.localized("Write today's page — a few quiet minutes, just for you.")
        content.sound = .default
        return content
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: allIDs)
    }

    static func reset() {
        cancel()
        SharedState.defaults.removeObject(forKey: enabledKey)
        SharedState.defaults.removeObject(forKey: reminderLastDayKey)
        SharedState.defaults.removeObject(forKey: reminderPromptsKey)
        SharedState.defaults.removeObject(forKey: journalMinutesKey)
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
