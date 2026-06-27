import SwiftUI

struct OnboardingWelcomeView: View {
    let stepIndex: Int
    let onContinue: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // Language pill
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                    Text("English")
                }
                .font(AppFont.bodySemibold(15))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Theme.card).clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.ink, lineWidth: Theme.borderWidth))
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Spacer()

            Image("WelcomeHero")
                .resizable().scaledToFit()
                .frame(width: 220, height: 220)
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)

            OnboardingHeader(eyebrow: "good morning,",
                             title: "welcome to your tiny morning ritual",
                             subtitle: "your little morning letter to yourself.",
                             subtitleScript: true,
                             alignment: .center)
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .opacity(appeared ? 1 : 0)

            Spacer()

            VStack(spacing: 14) {
                ProgressDots(count: OnboardingView.totalSteps, index: stepIndex)
                PrimaryButton(title: "let's begin →", action: onContinue)
                    .padding(.horizontal, 28)
                Text("takes 2 minutes · pinky promise")
                    .font(AppFont.accent(15))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(.bottom, 36)
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appeared = true } }
    }
}
