import SwiftUI

// MARK: - Primary CTA (full-width amber pill) — the prototype's main button

struct PrimaryButton: View {
    let title: String
    var enabled: Bool = true
    var color: Color = Palette.amber
    var textColor: Color = .white
    var action: () -> Void

    var body: some View {
        Button {
            guard enabled else { return }
            Haptics.tap(); action()
        } label: {
            Text(title)
                .font(Fonts.ui(16.5, .heavy))
                .foregroundStyle(enabled ? textColor : Palette.inkSofter)
                .frame(maxWidth: Metrics.maxButtonWidth)          // capped, fluid below — never full-column
                .padding(.vertical, DesignScale.s(16))
                .background(
                    enabled ? AnyShapeStyle(color) : AnyShapeStyle(Palette.ink.opacity(0.06)),
                    in: RoundedRectangle(cornerRadius: DesignScale.s(17), style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DesignScale.s(17), style: .continuous)
                    .stroke(Palette.ink, lineWidth: enabled ? 2 : 0))
                .tactile(enabled ? 4 : 0, cornerRadius: DesignScale.s(17))   // hard ink ledge — the "drawn" look
                .frame(maxWidth: .infinity)                       // center the capped pill in its parent
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .animation(Motion.snappy, value: enabled)
    }
}

/// The cream on-amber CTA — a light button that sits inside an amber card (Home "Write today's
/// page", Celebration "Start my day"). Cream fill, ink border, hard tactile shadow, amber-deep text.
struct CreamButton: View {
    let title: String
    var fill: Color = Palette.onAmber
    var textColor: Color = Palette.amberDeep
    var arrow: Bool = true
    var action: () -> Void

    var body: some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: 9) {
                Text(title).font(Fonts.ui(16, .heavy)).foregroundStyle(textColor)
                if arrow {
                    Image(systemName: "arrow.right")
                        .font(.system(size: DesignScale.s(14), weight: .bold)).foregroundStyle(textColor)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignScale.s(15))
            .background(fill, in: RoundedRectangle(cornerRadius: DesignScale.s(16), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DesignScale.s(16), style: .continuous)
                .stroke(Palette.ink, lineWidth: 2))
            .tactile(4, cornerRadius: DesignScale.s(16))
        }
        .buttonStyle(PressableStyle())
    }
}

struct GhostButton: View {
    let title: String
    var color: Color = Palette.inkSofter
    var action: () -> Void
    var body: some View {
        Button { Haptics.tap(); action() } label: {
            Text(title).font(Fonts.ui(14.5, .bold)).foregroundStyle(color)
                .frame(maxWidth: Metrics.maxButtonWidth).padding(.vertical, DesignScale.s(14))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }
}

// MARK: - Press feedback

struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(Motion.bouncy, value: configuration.isPressed)
    }
}

// MARK: - Soft white card

struct SoftCard: ViewModifier {
    var padding: CGFloat = 18
    var radius: CGFloat = 22
    var emphasized: Bool = false          // 2px solid ink vs 1.5px soft outline
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: DesignScale.s(radius), style: .continuous)
        content
            .padding(DesignScale.s(padding))
            .background(Palette.cream, in: shape)
            .overlay(shape.stroke(emphasized ? Palette.ink : Palette.outlineSoft,
                                  lineWidth: emphasized ? 2 : 1.5))
            .shadow(color: Color(hex: "78501E").opacity(0.09), radius: DesignScale.s(13), x: 0, y: DesignScale.s(10))
    }
}

extension View {
    func softCard(padding: CGFloat = 18, radius: CGFloat = 22, emphasized: Bool = false) -> some View {
        modifier(SoftCard(padding: padding, radius: radius, emphasized: emphasized))
    }
}

// MARK: - Icon tiles (rounded-square, black-outlined — the redesign's icon container)

/// Non-interactive icon container: cream/amber-cream fill + 2px ink border. Holds a sun, check, etc.
struct IconTile<Content: View>: View {
    var size: CGFloat = 38
    var fill: Color = Palette.iconTile
    var radius: CGFloat = 11
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .frame(width: DesignScale.s(size), height: DesignScale.s(size))
            .background(fill, in: RoundedRectangle(cornerRadius: DesignScale.s(radius), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DesignScale.s(radius), style: .continuous)
                .stroke(Palette.ink, lineWidth: 2))
    }
}

/// Tappable icon tile (close / back / share / month arrows).
struct IconTileButton: View {
    let icon: String
    var size: CGFloat = 38
    var iconSize: CGFloat = 14
    var iconColor: Color = Palette.ink
    var fill: Color = Palette.cream
    var radius: CGFloat = 11
    var action: () -> Void
    var body: some View {
        Button { Haptics.tap(); action() } label: {
            IconTile(size: size, fill: fill, radius: radius) {
                Image(systemName: icon)
                    .font(.system(size: DesignScale.s(iconSize), weight: .bold))
                    .foregroundStyle(iconColor)
            }
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Small circular icon button (close / back / month arrows)

struct SoftCircleButton: View {
    let icon: String                    // SF Symbol
    var diameter: CGFloat = 38
    var iconSize: CGFloat = 14
    var iconColor: Color = Palette.inkSoft
    var fill: Color = Palette.ink.opacity(0.06)
    var shadow: Bool = false
    var action: () -> Void

    var body: some View {
        Button { Haptics.tap(); action() } label: {
            Image(systemName: icon)
                .font(.system(size: DesignScale.s(iconSize), weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: DesignScale.s(diameter), height: DesignScale.s(diameter))
                .background(shadow ? AnyShapeStyle(Color.white) : AnyShapeStyle(fill), in: Circle())
                .shadow(color: shadow ? Color(hex: "78501E").opacity(0.08) : .clear, radius: 12, y: 4)
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Progress indicators

struct RitualPips: View {
    let step: Int          // 0…2 are lit as reached
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Palette.amber : Palette.ink.opacity(0.10))
                    .frame(height: DesignScale.s(6))
                    .frame(maxWidth: .infinity)
            }
        }
        .animation(Motion.snappy, value: step)
    }
}

struct PagerDots: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Palette.amber : Palette.ink.opacity(0.14))
                    .frame(width: DesignScale.s(i == index ? 20 : 7), height: DesignScale.s(7))
            }
        }
        .animation(Motion.snappy, value: index)
    }
}

// MARK: - Toggle (the profile "morning nudge" switch)

struct AmberToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? Palette.amber : Palette.ink.opacity(0.18))
                .overlay(Capsule().stroke(Palette.ink, lineWidth: 2))
                .frame(width: 46, height: 27)
            Circle()
                .fill(.white)
                .overlay(Circle().stroke(Palette.ink, lineWidth: 1.5))
                .frame(width: 21, height: 21)
                .padding(2.5)
        }
        .animation(Motion.snappy, value: isOn)
        .onTapGesture { Haptics.select(); isOn.toggle() }
    }
}
