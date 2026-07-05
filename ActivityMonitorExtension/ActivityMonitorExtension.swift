import DeviceActivity
import ManagedSettings
import Foundation

/// Runs the daily morning window without the app. At 04:00 it re-shields the chosen
/// apps (unless the ritual is somehow already done); at 23:59 it lifts the block.
final class ActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // Blocking is a premium feature — a subscription that lapsed while the app was never
        // reopened must not get re-shielded off a stale schedule.
        guard SharedState.premiumActive else { Shielding.clear(); return }
        // A fresh morning: shield unless today's ritual is already complete.
        if SharedState.ritualCompleted() {
            Shielding.clear()
        } else {
            Shielding.applySaved()
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // 23:59 — the day is nearly over; apps rest easy until tomorrow.
        Shielding.clear()
    }
}
