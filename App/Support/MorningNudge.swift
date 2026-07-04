import Foundation
import UserNotifications

enum MorningNudge {
    static let id = "honestly.morning.nudge"

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func schedule() {
        let content = UNMutableNotificationContent()
        content.title = "Honestly"   // brand name — not localized
        content.body = String(localized: "Good morning. Your page is waiting — the world can hold on a minute.",
                              locale: Locale(identifier: SharedState.language))
        content.sound = .default

        var when = DateComponents(); when.hour = 6; when.minute = 45
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
