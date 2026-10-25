import SwiftUI

struct RootView: View {
    @Environment(AppFlow.self) private var flow
    @AppStorage(SharedState.Key.onboardingComplete, store: SharedState.defaults)
    private var onboarded = false
    @State private var showSplash = !ScreenshotPreview.enabled

    var body: some View {
        @Bindable var flow = flow
        ZStack {
            Group {
                if ScreenshotPreview.screen == "write" {
                    RitualView(onClose: {})
                } else if ScreenshotPreview.screen == "affirmations" {
                    NavigationStack { AffirmationReaderScreen() }
                } else if ScreenshotPreview.screen == "affirmation-reader" {
                    NavigationStack { AffirmationReaderScreen() }
                } else if !onboarded && !ScreenshotPreview.enabled {
                    OnboardingView(onFinish: { onboarded = true })
                } else {
                    MainTabView()
                }
            }
            .fullScreenCover(isPresented: $flow.ritualPresented) {
                RitualView(onClose: { flow.ritualPresented = false })
            }
            // Gated on `!ritualPresented`: this same `Group` already has one active cover slot
            // taken by Ritual, so a second `.fullScreenCover` here can't also present while
            // Ritual is up — SwiftUI just queues it silently until Ritual dismisses ("Currently,
            // only presenting a single sheet is supported…"). RitualView carries its own copy of
            // this exact modifier for that case, presenting the paywall on top of itself
            // directly. This copy only needs to fire for triggers from screens Root isn't
            // covering with anything else (Home/History/Profile), so it steps aside whenever
            // Ritual owns the cover slot instead of racing it.
            .fullScreenCover(isPresented: Binding(
                get: { flow.paywallPresented && !flow.ritualPresented },
                set: { if !$0 { flow.paywallPresented = false } }
            )) {
                PaywallView(onClose: { flow.paywallPresented = false })
            }
            .animation(Motion.gentle, value: onboarded)

            if showSplash {
                SplashView { showSplash = false }
                    .transition(.opacity)
            }
        }
    }
}
