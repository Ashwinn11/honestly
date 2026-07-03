import SwiftUI

/// The top of the tree: gate on onboarding, host the main tabs, and present the two modal flows
/// (ritual + paywall) over everything.
struct RootView: View {
    @Environment(AppFlow.self) private var flow
    @AppStorage(SharedState.Key.onboardingComplete, store: SharedState.defaults)
    private var onboarded = false

    var body: some View {
        @Bindable var flow = flow
        Group {
            if onboarded {
                MainTabView()
            } else {
                OnboardingView(onFinish: { onboarded = true })
            }
        }
        .fullScreenCover(isPresented: $flow.ritualPresented) {
            RitualView(onClose: { flow.ritualPresented = false })
        }
        .fullScreenCover(isPresented: $flow.paywallPresented) {
            PaywallView(onClose: { flow.paywallPresented = false })
        }
        .animation(Motion.gentle, value: onboarded)
    }
}
