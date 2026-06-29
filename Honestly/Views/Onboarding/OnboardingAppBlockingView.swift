import SwiftUI

/// The "reclaim" tension beat: show the apps that hijack the morning, locked —
/// then unlocking — to make the focus-shield promise concrete before we ask for it.
struct OnboardingAppBlockingView: View {
    let stepIndex: Int
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            AppLockShowcase(tile: 62)
                .padding(.vertical, 28)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .appCardStyle(fill: Theme.card)
                .padding(.horizontal, 24)

            OnboardingHeader(eyebrow: "the honest trap —",
                             title: "the apps are built to keep you.",
                             subtitle: "locked until you've had your three minutes. then they're yours — guilt-free.",
                             subtitleScript: true,
                             alignment: .center)
                .padding(.horizontal, 28)
                .padding(.top, 24)

            Spacer()

            OnboardingBottomBar(stepIndex: stepIndex, primaryTitle: "keep going",
                                onBack: onBack, onPrimary: onNext)
        }
    }
}
