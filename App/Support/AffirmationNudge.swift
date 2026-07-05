import Foundation
import UserNotifications

/// Resurfaces one of the user's own past affirmations as a local notification whenever there's
/// one to quote; falls back to `AppContent.defaultAffirmation` before they've written their
/// first one, so the nudge still lands rather than silently never firing. There's no separate
/// "come write today" reminder (the Screen Time shield already does that job), so this is the
/// app's only nudge. Scheduled once per completed ritual (see `RitualView.finish()`).
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
    /// whenever there's an alternative. Uses the default line when `pool` is empty. No-op only if
    /// reminders are off.
    static func scheduleNext(from pool: [String]) {
        guard isEnabled else { return }
        let lines = pool.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        let d = SharedState.defaults
        let line: String
        if lines.isEmpty {
            // Not SwiftUI here, so `Text(loc:)` doesn't apply — do the String Catalog lookup directly.
            line = String(localized: String.LocalizationValue(AppContent.defaultAffirmation))
        } else {
            let last = d.string(forKey: lastSentKey)
            let candidates = lines.count > 1 ? lines.filter { $0 != last } : lines
            line = candidates.randomElement() ?? lines[0]
        }
        d.set(line, forKey: lastSentKey)

        let content = UNMutableNotificationContent()
        // Not SwiftUI here, so `Text(loc:)` doesn't apply — do the String Catalog lookup directly.
        content.title = String(localized: "Today's affirmation")
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
