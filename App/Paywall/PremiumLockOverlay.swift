import SwiftUI

// MARK: - Premium lock UI — the only lock visuals in the app

/// The small lock on anything Premium: a coral disc with a white lock and an ink rim. Themes,
/// sticker packs, the photo button and locked month covers all wear this one.
struct PremiumLockBadge: View {
    var size: CGFloat = 16

    init(size: CGFloat = 16) { self.size = size }

    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Palette.amber, in: Circle())
            .overlay(Circle().strokeBorder(Palette.ink, lineWidth: max(1, size * 0.07)))
            .accessibilityLabel(Text("Premium"))
    }
}

/// A row standing in for something Premium — "Write your own with Premium", "Unlock this widget
/// with Premium" — that opens the paywall.
struct PremiumLockedRow: View {
    let title: String                    // String Catalog key
    let action: () -> Void

    init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill").foregroundStyle(Palette.inkSofter)
                Text(loc: title)
                    .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSofter)
                Spacer()
            }
            .padding(14).frame(minHeight: 48)
            .outlinedSurface(radius: Radius.control)
        }
        .buttonStyle(.plain)
    }
}

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
                IconTile(size: 48, radius: Radius.control) {
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
                    .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2))
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableStyle(scale: 0.97))
        .softCard(padding: 0, radius: Radius.card, emphasized: true)
    }
}
