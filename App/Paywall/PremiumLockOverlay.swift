import SwiftUI

/// Generic "unlock" card used in place of premium-gated content (e.g. the History tab when locked).
/// Centered icon + short pitch + amber CTA pill, styled like the rest of the design system's
/// cream/ink cards.
struct PremiumUnlockCard: View {
    var icon: String = "lock.fill"
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                IconTile(size: 48, radius: 16) {
                    Image(systemName: icon).font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Palette.amberDeep)
                }
                VStack(spacing: 5) {
                    Text(loc: title).font(Fonts.display(18, .bold)).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                    Text(loc: subtitle).font(Fonts.ui(13, .semibold)).foregroundStyle(Palette.inkSofter)
                        .multilineTextAlignment(.center).lineSpacing(2)
                }
                Text(loc: "Unlock Premium").font(Fonts.ui(13.5, .heavy)).foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Palette.amber, in: Capsule())
            }
            .padding(24)
            .frame(maxWidth: 280)
        }
        .buttonStyle(PressableStyle(scale: 0.97))
        .softCard(padding: 0, radius: 22, emphasized: true)
    }
}
