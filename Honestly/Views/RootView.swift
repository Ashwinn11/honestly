import SwiftUI

/// Decides onboarding vs main app, configures services, runs launch tasks.
struct RootView: View {
    @EnvironmentObject var journalManager: JournalManager
    @EnvironmentObject var blockingManager: BlockingManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    @AppStorage(AppConstants.keyHasCompletedOnboarding,
                store: UserDefaults(suiteName: AppConstants.appGroupIdentifier))
    private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .task { await launch() }
    }

    private func launch() async {
        subscriptionManager.configure(apiKey: AppSecrets.revenueCatAPIKey)
        journalManager.resetForNewDay()
        AppConstants.scheduleBackgroundNotifRefresh()

        // Keep the daily 4 AM DeviceActivity schedule armed so the extension can
        // block apps before the app is even opened.
        if blockingManager.blockingEnabled {
            blockingManager.scheduleMonitoring()
        }

        // If we're inside the window right now and not yet done, block immediately.
        let hour = Calendar.current.component(.hour, from: Date())
        if AppConstants.isWithinSchedule(hour: hour),
           !journalManager.isCompletedToday,
           blockingManager.blockingEnabled {
            blockingManager.startBlocking()
        }
    }
}
