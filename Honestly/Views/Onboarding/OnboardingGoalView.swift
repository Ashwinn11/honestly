import SwiftUI

struct OnboardingGoalView: View {
    let stepIndex: Int
    @Binding var selected: Goal
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    OnboardingHeader(eyebrow: "your morning, your way —",
                                     title: "what do you want your morning to feel like?",
                                     subtitle: "this shapes what you write about every day.")

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(Goal.allCases) { goal in
                            card(goal)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 20)
            }

            OnboardingBottomBar(stepIndex: stepIndex, primaryTitle: "that's the one",
                                primaryIcon: "sparkles",
                                onBack: onBack, onPrimary: onNext)
        }
    }

    private func card(_ goal: Goal) -> some View {
        let isSelected = selected == goal
        return Button { selected = goal } label: {
            VStack(alignment: .leading, spacing: 10) {
                ColorIconBadge(icon: goal.icon, color: goal.color, size: 48)
                Text(goal.displayName)
                    .font(AppFont.bodyBold(20))
                    .foregroundStyle(Theme.ink)
                Text(goal.tagline)
                    .font(AppFont.accent(16))
                    .foregroundStyle(Theme.inkFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .appCardStyle(fill: isSelected ? Theme.orange.opacity(0.12) : Theme.card,
                          borderColor: isSelected ? Theme.orange : Theme.ink)
        }
        .buttonStyle(.plain)
    }
}
