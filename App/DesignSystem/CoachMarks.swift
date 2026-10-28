import SwiftUI

// MARK: - First-time tips

enum CoachAnchor: Hashable { case mood, prompt }

/// Where the things a tip points at sit on screen.
struct CoachAnchorKey: PreferenceKey {
    static let defaultValue: [CoachAnchor: Anchor<CGRect>] = [:]
    static func reduce(value: inout [CoachAnchor: Anchor<CGRect>], nextValue: () -> [CoachAnchor: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

/// A tip card hanging from what it explains, with a small arrow pointing up at it. One at a time:
/// "Next"/"Got it" moves on, ✕ ends the tips for good.
struct CoachMarkCard<Extra: View>: View {
    let title: String                    // String Catalog keys
    let message: String
    let step: Int
    let steps: Int
    let arrowX: CGFloat                  // from the card's leading edge
    var onNext: () -> Void
    var onDismiss: () -> Void
    var extra: Extra

    init(title: String, message: String, step: Int, steps: Int, arrowX: CGFloat,
         onNext: @escaping () -> Void, onDismiss: @escaping () -> Void,
         @ViewBuilder extra: () -> Extra) {
        self.title = title
        self.message = message
        self.step = step
        self.steps = steps
        self.arrowX = arrowX
        self.onNext = onNext
        self.onDismiss = onDismiss
        self.extra = extra()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Text(loc: title).font(Fonts.ui(15, .heavy)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button { Haptics.tap(); onDismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(width: 32, height: 32).contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle(scale: 0.88))
                .padding(.top, -8).padding(.trailing, -8)
                .accessibilityLabel(Text("Dismiss tips"))
            }
            Text(loc: message)
                .font(Fonts.ui(13, .semibold)).foregroundStyle(Palette.inkSoft)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            extra.padding(.top, 10)
            HStack {
                Text("\(step) of \(steps)").font(Fonts.ui(11, .heavy)).foregroundStyle(Palette.inkMuted)
                Spacer()
                Button { Haptics.tap(); onNext() } label: {
                    Text(loc: step == steps ? "Got it" : "Next")
                        .font(Fonts.ui(13, .heavy)).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 16).frame(minHeight: 36)
                        .background(Palette.amber, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2))
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.top, 12)
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 14))
        .background(Palette.cream, in: shape)
        .overlay(shape.strokeBorder(Palette.ink, lineWidth: 2))
        .tactile(4, cornerRadius: Radius.panel)
        .overlay(alignment: .topLeading) {
            // The arrow: a rotated square whose top half pokes out above the card.
            Rectangle()
                .fill(Palette.cream)
                .frame(width: 14, height: 14)
                .overlay(alignment: .topLeading) {
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: 14)); p.addLine(to: .zero); p.addLine(to: CGPoint(x: 14, y: 0))
                    }
                    .stroke(Palette.ink, lineWidth: 2)
                }
                .rotationEffect(.degrees(45))
                .offset(x: arrowX - 7, y: -7)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}
