import SwiftUI

/// Today-tab content shown once the ritual is complete for the day.
struct ShowedUpView: View {
    @EnvironmentObject var journalManager: JournalManager

    // Scattered confetti accents: (xOffset, yOffset, color, isCircle, rotation)
    private let confetti: [(CGFloat, CGFloat, Color, Bool, Double)] = [
        (-104, -86, Theme.cry,      false, 18), (-58, -112, Theme.confused, true, 0),
        ( 12, -120, Theme.sad,      false, -12), ( 96, -96, Theme.happy,    true, 0),
        (118, -44, Theme.cry,       false, 24), (-118, 4, Theme.orange,     true, 0),
        ( 70, -130, Theme.confused, true, 0),
    ]

    var body: some View {
        VStack(spacing: 20) {
            // The plant (current stage) + a "done!" bubble, ringed by confetti.
            ZStack(alignment: .topTrailing) {
                ForEach(Array(confetti.enumerated()), id: \.offset) { _, c in
                    Group {
                        if c.3 {
                            Circle().fill(c.2)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
                        } else {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(c.2)
                                .frame(width: 12, height: 12)
                                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.ink, lineWidth: 2))
                                .rotationEffect(.degrees(c.4))
                        }
                    }
                    .offset(x: c.0, y: c.1)
                }

                Circle()
                    .fill(Theme.happy.opacity(0.55))
                    .overlay(Circle().stroke(Theme.ink, lineWidth: Theme.borderWidth))
                    .frame(width: 220, height: 220)
                    .overlay(
                        PlantView(stage: journalManager.currentStage, size: 130)
                    )

                speechBubble
                    .offset(x: 18, y: -8)
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                Eyebrow("yay, you", size: 22)
                Text("showed up\ntoday.")
                    .font(AppFont.display(38))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("your apps are unlocked. go gently.")
                    .font(AppFont.body(16))
                    .foregroundStyle(Theme.inkFaint)

                sproutPill
                    .padding(.top, 6)
            }
        }
    }

    private var sproutPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("+1 sprout")
                .font(AppFont.captionBold(14))
                .foregroundStyle(Theme.ink)
            Text("· \(journalManager.sproutCount) in your garden")
                .font(AppFont.accent(16))
                .foregroundStyle(Theme.inkFaint)
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
        .background(Theme.confused)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.ink, lineWidth: 2))
        .background(Capsule().fill(Theme.ink).offset(y: 4))
    }

    private var speechBubble: some View {
        HStack(spacing: 5) {
            Text("done!")
                .font(AppFont.accent(20))
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
        }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.ink, lineWidth: Theme.borderWidth))
    }
}
