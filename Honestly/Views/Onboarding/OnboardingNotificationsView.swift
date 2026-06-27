import SwiftUI

struct OnboardingNotificationsView: View {
    let stepIndex: Int
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                PlantView(stage: .young, size: 120)
                    .padding(28)
                    .appCardStyle(fill: Theme.card)

                OnboardingHeader(eyebrow: "before you start —",
                                 title: "we'll tap you before the scroll",
                                 subtitle: "a gentle nudge each morning so honestly opens first.",
                                 subtitleScript: true,
                                 alignment: .center)
                    .padding(.horizontal, 28)
            }

            Spacer()

            OnboardingBottomBar(stepIndex: stepIndex, primaryTitle: "yes, remind me",
                                primaryIcon: "bell.fill",
                                secondaryTitle: "skip for now",
                                onBack: onBack,
                                onPrimary: {
                                    Task {
                                        await NotificationManager.shared.requestPermission()
                                        NotificationManager.shared.scheduleMorningReminder()
                                        onNext()
                                    }
                                },
                                onSecondary: onNext)
        }
    }
}
