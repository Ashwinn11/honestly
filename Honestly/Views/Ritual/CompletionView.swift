import SwiftUI

/// Single celebration overlay shown right after finishing the ritual: the
/// sprout-count card. Dismissing returns to Today (which flips to its
/// "showed up today" state). The garden-stages guide is NOT shown here —
/// it lives behind the Today header pot.
struct CompletionView: View {
    let stage: PlantStage
    let sproutCount: Int
    let onDone: () -> Void

    @State private var appeared = false

    private var headline: String {
        sproutCount == 1 ? "first letter, written" : "another morning, done"
    }
    private var subcopy: String {
        sproutCount == 1 ? "welcome. this is where it starts." : "your plant is growing."
    }

    var body: some View {
        ZStack {
            Theme.ink.opacity(0.18).ignoresSafeArea()

            AppCard(padding: 28) {
                VStack(spacing: 16) {
                    PlantView(stage: stage, size: 96)

                    Eyebrow(headline, size: 24)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(sproutCount)")
                            .font(AppFont.title(30))
                            .foregroundStyle(Theme.ink)
                        Text(sproutCount == 1 ? "sprout" : "sprouts")
                            .font(AppFont.accent(20))
                            .foregroundStyle(Theme.inkFaint)
                    }

                    Text(LocalizedStringKey(subcopy))
                        .font(AppFont.body(16))
                        .foregroundStyle(Theme.inkFaint)

                    PrimaryButton(title: "done", action: onDone)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 460)
            .padding(.horizontal, 32)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
        }
    }
}
