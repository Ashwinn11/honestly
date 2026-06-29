import SwiftUI
import BackgroundTasks

@main
struct HonestlyApp: App {
    @StateObject private var journalManager = JournalManager()
    @StateObject private var blockingManager = BlockingManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var localizationManager = LocalizationManager.shared

    init() {
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(journalManager)
                .environmentObject(blockingManager)
                .environmentObject(subscriptionManager)
                .preferredColorScheme(.light)   // app is light-only
                .localized(localizationManager)

        }
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: AppConstants.bgNotifTaskID, using: nil) { task in
            NotificationManager.shared.scheduleMorningReminder()
            AppConstants.scheduleBackgroundNotifRefresh()
            task.setTaskCompleted(success: true)
        }
    }
}
