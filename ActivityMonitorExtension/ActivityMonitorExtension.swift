import DeviceActivity
import ManagedSettings
import Foundation
import UserNotifications

/// Runs the daily morning window without the app. At 04:00 it re-shields the chosen
/// apps (unless the ritual is somehow already done); at 23:59 it lifts the block.
final class ActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        Shielding.reconcile()
        // Runs even on days the app is never opened — the only trigger that reliably covers that
        // case, since everything else depends on the app or its UI actually being used.
        AffirmationNudge.scheduleReminderIfNeeded(ritualDoneToday: SharedState.ritualCompleted())
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // 23:59 — the day is nearly over; apps rest easy until tomorrow.
        Shielding.clear()
    }
}
