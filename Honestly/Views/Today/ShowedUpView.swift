import SwiftUI

/// Today-tab content shown once the ritual is complete for the day.
struct ShowedUpView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Sun-with-friends scene + "done!" bubble
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Theme.happy.opacity(0.55))
                    .overlay(Circle().stroke(Theme.ink, lineWidth: Theme.borderWidth))
                    .frame(width: 220, height: 220)
                    .overlay(
                        VStack(spacing: 6) {
                            Mascot(kind: .sun, size: 84)
                            HStack(spacing: 14) {
                                Mascot(kind: .flower, size: 46)
                                Mascot(kind: .mushroom, size: 46)
                            }
                        }
                    )
                    .overlay(alignment: .bottomLeading) {
                        Mascot(kind: .clover, size: 34).offset(x: -6, y: 6)
                    }

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
            }
        }
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
