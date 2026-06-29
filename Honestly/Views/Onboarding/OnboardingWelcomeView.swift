import SwiftUI

struct OnboardingWelcomeView: View {
    let stepIndex: Int
    let onContinue: () -> Void

    @State private var appeared = false
    @State private var showLanguagePicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Language pill — opens the live language chooser.
            HStack {
                Spacer()
                LanguagePill { showLanguagePicker = true }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Spacer()

            Image("WelcomeHero")
                .resizable().scaledToFit()
                .frame(width: AppLayout.s(220), height: AppLayout.s(220))
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)

            OnboardingHeader(eyebrow: "the morning you actually want",
                             title: "honestly.",
                             subtitle: "three quiet minutes, not the scroll.",
                             subtitleScript: true,
                             alignment: .center)
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .opacity(appeared ? 1 : 0)

            Spacer()

            VStack(spacing: 14) {
                ProgressDots(count: OnboardingView.totalSteps, index: stepIndex)
                PrimaryButton(title: "start my mornings", action: onContinue)
                    .padding(.horizontal, 28)
                Text("takes 2 minutes · pinky promise")
                    .font(AppFont.accent(15))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(.bottom, 36)
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appeared = true } }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView()
        }
    }
}
