import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var blockingManager: BlockingManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    @AppStorage(AppConstants.keyHasCompletedOnboarding, store: UserDefaults(suiteName: AppConstants.appGroupIdentifier))
    private var hasCompletedOnboarding = false

    @State private var step = 0
    @State private var scrollMinutes = 30
    @State private var goal: Goal = .clarity
    @State private var showPaywall = false

    static let totalSteps = 7

    var body: some View {
        ZStack {
            Theme.pageBackground

            content
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)))
                .id(step)
        }
        .animation(.easeInOut(duration: 0.3), value: step)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView { finish() }
                .environmentObject(subscriptionManager)
        }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case 0: OnboardingWelcomeView(stepIndex: 0) { advance() }
        case 1: OnboardingScrollTimeView(stepIndex: 1, minutes: $scrollMinutes,
                                         onNext: { advance() }, onBack: { back() })
        case 2: OnboardingGoalView(stepIndex: 2, selected: $goal,
                                   onNext: { advance() }, onBack: { back() })
        case 3: OnboardingHowItWorksView(stepIndex: 3, onNext: { advance() }, onBack: { back() })
        case 4: OnboardingPlantStagesView(stepIndex: 4, onNext: { advance() }, onBack: { back() })
        case 5: OnboardingNotificationsView(stepIndex: 5, onNext: { advance() }, onBack: { back() })
        case 6: OnboardingFocusShieldView(stepIndex: 6, onNext: { advance() }, onBack: { back() })
        default: Color.clear
        }
    }

    private func advance() {
        if step >= Self.totalSteps - 1 {
            persistChoices()
            showPaywall = true
        } else {
            step += 1
        }
    }

    private func back() { if step > 0 { step -= 1 } }

    private func persistChoices() {
        let d = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
        d?.set(scrollMinutes, forKey: AppConstants.keyScrollMinutes)
        d?.set(goal.rawValue, forKey: AppConstants.keyUserOutcome)
    }

    private func finish() {
        persistChoices()
        hasCompletedOnboarding = true
    }
}

// MARK: - Shared onboarding header (STRICT structure)
// Every onboarding screen uses this so the rhythm is identical:
//   1. orange Caveat eyebrow   2. LT Saeada headline   3. optional sub copy
struct OnboardingHeader: View {
    let eyebrow: String
    let title: String
    var subtitle: String? = nil
    var subtitleScript: Bool = false        // Caveat (true) vs LT Saeada (false)
    var alignment: HorizontalAlignment = .leading
    var titleSize: CGFloat = 30

    private var textAlign: TextAlignment { alignment == .center ? .center : .leading }

    var body: some View {
        VStack(alignment: alignment, spacing: 10) {
            Eyebrow(eyebrow, size: 20)
            Text(title)
                .font(AppFont.display(titleSize))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(textAlign)
                .lineSpacing(2)
            if let subtitle {
                Text(subtitle)
                    .font(subtitleScript ? AppFont.accent(18) : AppFont.body(16))
                    .foregroundStyle(Theme.inkFaint)
                    .multilineTextAlignment(textAlign)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }
}

// MARK: - Shared onboarding bottom bar

struct OnboardingBottomBar: View {
    let stepIndex: Int
    var showBack = true
    var primaryTitle: String
    var primaryIcon: String? = nil    // trailing SF Symbol
    var primaryFilled = true          // orange vs dark
    var secondaryTitle: String? = nil
    var onBack: () -> Void = {}
    let onPrimary: () -> Void
    var onSecondary: () -> Void = {}

    var body: some View {
        VStack(spacing: 16) {
            ProgressDots(count: OnboardingView.totalSteps, index: stepIndex)

            HStack(spacing: 14) {
                if showBack {
                    CircleIconButton(systemName: "chevron.left", action: onBack)
                        .frame(width: 70)
                }
                PrimaryButton(title: primaryTitle,
                              fill: primaryFilled ? Theme.orange : Theme.dark,
                              action: onPrimary)
            }

            if let secondaryTitle {
                Button(action: onSecondary) {
                    Text(secondaryTitle)
                        .font(AppFont.accent(16))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 36)
    }
}
