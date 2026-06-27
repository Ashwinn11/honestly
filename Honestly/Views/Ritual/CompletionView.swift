import SwiftUI

/// Two-stage completion: (1) "first letter, written" celebration card,
/// (2) "your garden stages" educational sheet. Then returns home.
struct CompletionView: View {
    let stage: PlantStage
    let sproutCount: Int
    let onDone: () -> Void

    @State private var showStages = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Dimmed sun scene behind the celebration.
            VStack {
                ZStack(alignment: .topTrailing) {
                    Mascot(kind: .sun, size: 110)
                    Text("done! ✓")
                        .font(AppFont.accent(20))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.ink, lineWidth: Theme.borderWidth))
                        .offset(x: 36, y: -10)
                }
                .padding(.top, 80)
                Spacer()
            }

            if showStages {
                gardenStagesSheet.transition(.move(edge: .bottom))
            } else {
                celebrationCard
                    .scaleEffect(appeared ? 1 : 0.85)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true } }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: showStages)
    }

    // MARK: Stage 1

    private var celebrationCard: some View {
        AppCard(padding: 28) {
            VStack(spacing: 16) {
                PlantView(stage: stage, size: 96)
                HStack(spacing: 6) {
                    Text("first letter, written")
                        .font(AppFont.eyebrow(26))
                        .foregroundStyle(Theme.orange)
                    Text("🌱")
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(sproutCount)")
                        .font(AppFont.title(30))
                        .foregroundStyle(Theme.ink)
                    Text("sprouts")
                        .font(AppFont.accent(20))
                        .foregroundStyle(Theme.inkFaint)
                }
                Text("welcome. this is where it starts.")
                    .font(AppFont.body(16))
                    .foregroundStyle(Theme.inkFaint)

                PrimaryButton(title: "see your garden") {
                    showStages = true
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 32)
    }

    // MARK: Stage 2

    private var gardenStagesSheet: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 18) {
                Capsule().fill(Theme.inkGhost).frame(width: 40, height: 5)
                    .frame(maxWidth: .infinity)

                VStack(spacing: 6) {
                    Eyebrow("your garden stages", size: 24)
                        .frame(maxWidth: .infinity)
                    Text("journal every day to grow. miss days and your plant gently steps back.")
                        .font(AppFont.accent(17))
                        .foregroundStyle(Theme.inkFaint)
                        .multilineTextAlignment(.center)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(PlantStage.allCases) { s in
                        stageCard(s)
                    }
                }

                PrimaryButton(title: "back to home", action: onDone)
                    .padding(.top, 6)
            }
            .padding(24)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(Theme.ink, lineWidth: Theme.borderWidth))
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func stageCard(_ s: PlantStage) -> some View {
        let isCurrent = s == stage
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
        .background(isCurrent ? Theme.confused.opacity(0.35) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
