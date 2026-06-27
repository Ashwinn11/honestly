import Foundation
import DeviceActivity
import ManagedSettings
import FamilyControls

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("morningBlock"))
    private let defaults = UserDefaults(suiteName: "group.morning-journal.app")

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity.rawValue == "MorningJournal.MorningBlock" else { return }
        guard let defaults else { return }

        let blockingEnabled = defaults.bool(forKey: "blockingEnabled")
        let isCompleted = isJournalCompletedToday(in: defaults)

        if blockingEnabled && !isCompleted {
            applyBlock()
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity.rawValue == "MorningJournal.MorningBlock" else { return }
        store.clearAllSettings()
        defaults?.set(false, forKey: "isCurrentlyBlocking")
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
    }

    // MARK: - Private

    private func applyBlock() {
        guard let data = defaults?.data(forKey: "familyActivitySelection"),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }

        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
        }
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }
        defaults?.set(true, forKey: "isCurrentlyBlocking")
    }

    private func isJournalCompletedToday(in defaults: UserDefaults) -> Bool {
        let completed = defaults.bool(forKey: "todayCompleted")
        guard completed else { return false }
        if let lastDate = defaults.object(forKey: "lastCompletionDate") as? Date {
            return Calendar.current.isDateInToday(lastDate)
        }
        return false
    }
}
