import SwiftUI

struct RootView: View {
    @Environment(AppFlow.self) private var flow
    @Environment(PremiumManager.self) private var premium
    @AppStorage(SharedState.Key.onboardingComplete, store: SharedState.defaults)
    private var onboarded = false

    var body: some View {
        @Bindable var flow = flow
        Group {
            if !onboarded {
                OnboardingView(onFinish: { onboarded = true })
            } else if !premium.isPremium {
                PaywallView(gate: true, onClose: {})
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
        .animation(Motion.gentle, value: premium.isPremium)
    }
}
