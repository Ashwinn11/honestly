import SwiftUI

struct OnboardingPlantStagesView: View {
    let stepIndex: Int
    let onNext: () -> Void
    let onBack: () -> Void

    private let stages: [(PlantStage, String)] = [
        (.sprout, "0"), (.young, "10"), (.leafy, "30"), (.lush, "90"), (.bloom, "180"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    OnboardingHeader(eyebrow: "take care of",
                                     title: "your little plant",
                                     subtitle: "show up every morning and watch it bloom. miss a day and it needs you back.")

                    HStack(spacing: 6) {
                        ForEach(Array(stages.enumerated()), id: \.offset) { _, item in
                            VStack(spacing: 5) {
                                PlantView(stage: item.0, size: 44)
                                    .padding(7)
                                    .appCardStyle(radius: 14, fill: item.0.bgTint)
                                Text(item.1)
                                    .font(AppFont.accent(15))
                                    .foregroundStyle(Theme.orange)
                                Text(item.0.displayName)
                                    .font(AppFont.caption(10))
                                    .foregroundStyle(Theme.inkFaint)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    HStack(spacing: 14) {
                        comparison(title: "show up", icon: "checkmark.circle.fill",
                                   tint: Theme.orange, plant: .bloom, bg: Theme.confused.opacity(0.3))
                        comparison(title: "miss a day", icon: "xmark.circle.fill",
                                   tint: Theme.inkFaint, plant: .sprout, bg: Theme.card)
                    }

                    HStack(spacing: 6) {
                        PlantView(stage: .sprout, size: 30)
                        Text("each time you check in, you plant a sprout.")
                            .font(AppFont.accent(17))
                            .foregroundStyle(Theme.orange)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 20)
            }

            OnboardingBottomBar(stepIndex: stepIndex, primaryTitle: "continue",
                                onBack: onBack, onPrimary: onNext)
        }
    }

    private func comparison(title: String, icon: String, tint: Color, plant: PlantStage, bg: Color) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(title).font(AppFont.bodyBold(17)).foregroundStyle(Theme.ink)
            }
            PlantView(stage: plant, size: 56)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .appCardStyle(fill: bg)
    }
}

private extension PlantStage {
    var bgTint: Color {
        switch self {
        case .sprout, .young, .leafy: return Theme.confused.opacity(0.3)
        case .lush:                   return Theme.happy.opacity(0.3)
        case .bloom:                  return Theme.sad.opacity(0.3)
        }
    }
}
