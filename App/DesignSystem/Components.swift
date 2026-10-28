import SwiftUI

// MARK: - Primary CTA (full-width amber pill) — the prototype's main button

struct PrimaryButton: View {
    let title: LocalizedStringKey
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
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignScale.s(16))
        }
        .buttonStyle(TactileButtonStyle(
            fill: enabled ? AnyShapeStyle(color) : AnyShapeStyle(Palette.ink.opacity(0.06)),
            cornerRadius: DesignScale.s(17), ledge: enabled ? 4 : 0, bordered: enabled))
        .frame(maxWidth: Metrics.maxButtonWidth)          // capped on iPad…
        .frame(maxWidth: .infinity)                       // …centered in its parent
        .disabled(!enabled)
        .animation(Motion.snappy, value: enabled)
    }
}

/// Key-press physics: the fill sinks toward its fixed ink ledge on touch (the gap closes), with a
/// hair of scale. The interactive replacement for the static `.tactile()` on CTAs.
struct TactileButtonStyle: ButtonStyle {
    var fill: AnyShapeStyle
    var cornerRadius: CGFloat
    var ledge: CGFloat = 4
    var bordered: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return configuration.label
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(Palette.ink, lineWidth: bordered ? 2 : 0))
            .scaleEffect(pressed ? 0.99 : 1)
            .offset(y: pressed ? max(ledge - 1, 0) : 0)                 // sink onto the ledge
            .background(shape.fill(ledge > 0 ? Palette.ink : Color.clear).offset(y: ledge))
            .animation(Motion.press, value: pressed)
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
                Text(loc: title).font(Fonts.ui(16, .heavy)).foregroundStyle(textColor)
                if arrow {
                    Image(systemName: "arrow.forward")
                        .font(.system(size: DesignScale.s(14), weight: .bold)).foregroundStyle(textColor)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignScale.s(15))
        }
        .buttonStyle(TactileButtonStyle(fill: AnyShapeStyle(fill),
                                        cornerRadius: DesignScale.s(16), ledge: 4, bordered: true))
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
            .overlay(shape.strokeBorder(emphasized ? Palette.ink : Palette.outlineSoft,
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
                .strokeBorder(Palette.ink, lineWidth: 2))
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
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Compact tool controls — shared by text formatting and drawing

enum CompactControlMetrics {
    static let size: CGFloat = 36
    static let iconSize: CGFloat = 14
    static let radius: CGFloat = 10
    static let borderWidth: CGFloat = 1.2
}

private struct CompactControlSurface: ViewModifier {
    let active: Bool
    let fill: Color

    func body(content: Content) -> some View {
        content
            .foregroundStyle(active ? .white : Palette.ink)
            .frame(width: DesignScale.s(CompactControlMetrics.size), height: DesignScale.s(CompactControlMetrics.size))
            .background(active ? Palette.amber : fill,
                        in: RoundedRectangle(cornerRadius: DesignScale.s(CompactControlMetrics.radius), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DesignScale.s(CompactControlMetrics.radius), style: .continuous)
                .strokeBorder(active ? Palette.ink : Palette.outlineSoft,
                        lineWidth: active ? 2 : CompactControlMetrics.borderWidth))
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }
}

extension View {
    func compactControl(active: Bool = false, fill: Color = Palette.paper) -> some View {
        modifier(CompactControlSurface(active: active, fill: fill))
    }
}

struct CompactIconFace: View {
    let icon: String
    var active = false
    var fill = Palette.paper

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: DesignScale.s(CompactControlMetrics.iconSize), weight: .bold))
            .compactControl(active: active, fill: fill)
    }
}

// MARK: - Empty pages — the one empty state wherever pages are listed

/// A sun, a line saying what's missing, and an optional next step. Used by the Library's search
/// and filters, an empty month book, and a page that's gone.
struct EmptyPagesState: View {
    let title: String                    // String Catalog keys
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    init(title: String, message: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                SoftGlow(color: Palette.sunDisc, opacity: 0.2, size: 180)
                SunMark(size: 58).floaty(period: 5)
            }
            VStack(spacing: 7) {
                Text(loc: title)
                    .font(Fonts.display(21, .bold)).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                if let message {
                    Text(loc: message)
                        .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSofter)
                        .multilineTextAlignment(.center).lineSpacing(2)
                }
            }
            if let actionTitle, let action {
                Button { Haptics.tap(); action() } label: {
                    Text(loc: actionTitle).font(Fonts.ui(14, .heavy)).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 18).frame(minHeight: 46)
                }
                .buttonStyle(TactileButtonStyle(fill: AnyShapeStyle(Palette.onAmber),
                                                cornerRadius: DesignScale.s(14), ledge: 4, bordered: true))
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
    }
}

// MARK: - Toggle (the profile "morning nudge" switch)

struct AmberToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? Palette.amber : Palette.ink.opacity(0.18))
                .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2))
                .frame(width: 46, height: 27)
            Circle()
                .fill(.white)
                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 1.5))
                .frame(width: 21, height: 21)
                .padding(2.5)
        }
        .animation(Motion.snappy, value: isOn)
        .onTapGesture { Haptics.select(); isOn.toggle() }
    }
}
