import Foundation
import UserNotifications

/// Randomly resurfaces one of the user's own past affirmations as a local notification — never
/// canned content, always something they actually wrote. There's no separate "come write today"
/// reminder (the Screen Time shield already does that job), so this is the app's only nudge.
/// Scheduled once per completed ritual (see `RitualView.finish()`); silently no-ops if there's
/// nothing to quote yet or the user has turned reminders off.
enum AffirmationNudge {
    static let id = "honestly.affirmation.nudge"
    private static let enabledKey = "affirmationNudgeOn"
    private static let lastSentKey = "affirmationNudgeLastSent"

    static var isEnabled: Bool {
        let d = SharedState.defaults
        return d.object(forKey: enabledKey) == nil ? true : d.bool(forKey: enabledKey)
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Schedules one reminder a few hours out, quoting a random line from `pool` (the user's own
    /// affirmations across all entries) — avoiding an immediate repeat of the last one sent
    /// whenever there's an alternative. No-op if reminders are off or there's nothing to quote.
    static func scheduleNext(from pool: [String]) {
        guard isEnabled else { return }
        let lines = pool.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !lines.isEmpty else { return }

        let d = SharedState.defaults
        let last = d.string(forKey: lastSentKey)
        let candidates = lines.count > 1 ? lines.filter { $0 != last } : lines
        guard let line = candidates.randomElement() else { return }
        d.set(line, forKey: lastSentKey)

        let content = UNMutableNotificationContent()
        content.title = "Honestly"   // brand name — not localized
        content.body = line          // the user's own words — never translated/rewritten
        content.sound = .default

        let seconds = TimeInterval(Int.random(in: 2 * 3600...10 * 3600))   // 2–10 hours out
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
