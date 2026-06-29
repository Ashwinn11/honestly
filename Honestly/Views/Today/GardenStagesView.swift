import SwiftUI

/// The 4-stage plant guide. Presented as a sheet when the user taps the
/// pot / streak in the Today header — NOT automatically after the ritual.
struct GardenStagesView: View {
    var currentStage: PlantStage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.pageBackground
            VStack(spacing: 20) {
                Capsule().fill(Theme.inkGhost).frame(width: 40, height: 5)
                    .padding(.top, 10)

                VStack(spacing: 6) {
                    Eyebrow("your garden", size: 20)
                    Text("how your plant grows")
                        .font(AppFont.display(28))
                        .foregroundStyle(Theme.ink)
                    Text("journal every day to grow. miss days and your plant gently steps back.")
                        .font(AppFont.accent(17))
                        .foregroundStyle(Theme.inkFaint)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 14) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(Array(PlantStage.allCases.dropLast())) { stage in
                            stageCard(stage)
                        }
                    }
                    // Lone final stage (bloom) centered at one-column width.
                    if let last = PlantStage.allCases.last {
                        stageCard(last)
                            .containerRelativeFrame(.horizontal, count: 2, span: 1, spacing: 14)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }

    private func stageCard(_ s: PlantStage) -> some View {
        let isCurrent = s == currentStage
        return VStack(spacing: 8) {
            PlantView(stage: s, size: 64)
            Text(s.displayName)
                .font(AppFont.bodyBold(17))
                .foregroundStyle(isCurrent ? Theme.orange : Theme.ink)
            Text(s.range)
                .font(AppFont.accent(15))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .overlay(Capsule().stroke(Theme.ink, lineWidth: 1.5))
            Text(s.blurb)
                .font(AppFont.caption(13))
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .appCardStyle(fill: isCurrent ? Theme.confused : Theme.card,
                      borderColor: isCurrent ? Theme.ink : Theme.inkGhost)
    }
}
