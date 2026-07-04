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
                    enabled ? AnyShapeStyle(color) : AnyShapeStyle(Palette.ink.opacity(0.08)),
                    in: RoundedRectangle(cornerRadius: DesignScale.s(17), style: .continuous))
                .shadow(color: enabled ? color.opacity(0.32) : .clear, radius: DesignScale.s(11), y: DesignScale.s(10))
                .frame(maxWidth: .infinity)                       // center the capped pill in its parent
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .animation(Motion.snappy, value: enabled)
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
    var radius: CGFloat = 26
    func body(content: Content) -> some View {
        content
            .padding(DesignScale.s(padding))
            .background(.white, in: RoundedRectangle(cornerRadius: DesignScale.s(radius), style: .continuous))
            .shadow(color: Color(hex: "78501E").opacity(0.09), radius: DesignScale.s(15), x: 0, y: DesignScale.s(12))
    }
}

extension View {
    func softCard(padding: CGFloat = 18, radius: CGFloat = 26) -> some View {
        modifier(SoftCard(padding: padding, radius: radius))
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
                .frame(width: 44, height: 26)
            Circle()
                .fill(.white)
                .frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                .padding(2)
        }
        .animation(Motion.snappy, value: isOn)
        .onTapGesture { Haptics.select(); isOn.toggle() }
    }
}
