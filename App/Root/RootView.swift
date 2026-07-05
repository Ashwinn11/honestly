import SwiftUI

struct RootView: View {
    @Environment(AppFlow.self) private var flow
    @AppStorage(SharedState.Key.onboardingComplete, store: SharedState.defaults)
    private var onboarded = false

    var body: some View {
        @Bindable var flow = flow
        Group {
            if !onboarded {
                OnboardingView(onFinish: { onboarded = true })
            } else {
                MainTabView()
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
