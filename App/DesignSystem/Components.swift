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
                .frame(maxWidth: .infinity, minHeight: DesignScale.s(56))   // the height of a tile beside it
        }
        .buttonStyle(TactileButtonStyle(
            fill: enabled ? AnyShapeStyle(color) : AnyShapeStyle(Palette.ink.opacity(0.06)),
            cornerRadius: DesignScale.s(Radius.panel), ledge: enabled ? 4 : 0, bordered: enabled))
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
                                        cornerRadius: DesignScale.s(Radius.control), ledge: 4, bordered: true))
    }
}

// MARK: - Choice row

/// A row to pick: its title, and a tick circle that fills when it's chosen, the row turning amber
/// with an ink outline. Onboarding's answers and the affirmation topics.
struct ChoiceRow: View {
    let title: String                   // String Catalog key
    let selected: Bool
    /// Grid cells cap their lines and shrink to fit; full-width rows wrap freely.
    var lineLimit: Int? = nil
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
        Button(action: action) {
            HStack(spacing: 10) {
                Text(loc: title)
                    .font(Fonts.ui(14, .semibold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(lineLimit)
                    .minimumScaleFactor(lineLimit == nil ? 1 : 0.85)
                    .fixedSize(horizontal: false, vertical: lineLimit == nil)
                Spacer(minLength: 4)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(selected ? Palette.ink : Palette.outlineSoft)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(selected ? Palette.amber : Palette.cream, in: shape)
            .overlay(shape.strokeBorder(selected ? Palette.ink : Palette.outlineSoft, lineWidth: selected ? 1.8 : 1.2))
            .contentShape(shape)
        }
        .buttonStyle(PressableStyle(scale: 0.98))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Amber pill

/// The small amber call to action inside a row or card — "Upgrade", "Unlock Premium".
struct AmberPill: View {
    let title: String                   // String Catalog key

    var body: some View {
        Text(loc: title)
            .font(Fonts.ui(13.5, .heavy)).foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Palette.amber, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2))
    }
}

// MARK: - Colour swatch

/// One colour to pick, as a circle; the chosen one gets a heavier ink ring and a tick — ink on a
/// light colour, white on a dark one, so it always shows.
struct ColorSwatch: View {
    let color: Color
    let selected: Bool
    let action: () -> Void

    private var tick: Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: nil)
        return 0.299 * r + 0.587 * g + 0.114 * b > 0.6 ? Palette.ink : .white
    }

    var body: some View {
        Button(action: action) {
            Circle().fill(color)
                .frame(width: 32, height: 32)
                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: selected ? 2.5 : 0.5))
                .overlay {
                    if selected {
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .black)).foregroundStyle(tick)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Font chip

/// One font to pick, its name set in that font; the chosen one amber with a tick. A chip in a
/// row, or a cell filling its grid column.
struct FontChip: View {
    let choice: FontChoice
    let selected: Bool
    var fillsWidth = false
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        Button(action: action) {
            HStack(spacing: 5) {
                if selected { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
                Text(choice.rawValue).font(Font(choice.uiFont(size: 14)))
            }
            .foregroundStyle(selected ? .white : Palette.ink)
            .padding(.horizontal, 12)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .frame(height: fillsWidth ? 44 : 34)
            .background(selected ? AnyShapeStyle(Palette.amber) : AnyShapeStyle(Palette.paper), in: shape)
            .overlay(shape.strokeBorder(selected ? Palette.ink : Palette.outlineSoft, lineWidth: selected ? 2 : 1.2))
            .contentShape(shape)
        }
        .buttonStyle(PressableStyle(scale: 0.92))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Time row

/// A reminder's time: its name (and what it does) on the left, the system time picker on the right.
struct TimeRow: View {
    let title: String                   // String Catalog key
    var detail: String? = nil           // String Catalog key
    @Binding var minutes: Int           // after midnight

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(loc: title).font(Fonts.ui(15, .bold)).foregroundStyle(Palette.ink)
                if let detail {
                    Text(loc: detail).font(Fonts.ui(12, .medium)).foregroundStyle(Palette.inkSofter)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 4)
            DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(Palette.amber)
        }
    }

    private var time: Binding<Date> {
        Binding(get: {
            Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        })
    }
}

// MARK: - Chip tabs

/// A free-floating row of chips, one per section, the chosen one amber; it scrolls sideways when
/// it runs past the screen, so it never squeezes on a small phone. How the sticker, text
/// formatting, page theme and cover sheets switch between their sections.
struct ChipTabs<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String             // String Catalog key
    let icon: (Item) -> String              // SF Symbol
    /// The sheet's side margin: the chips start in line with its content but scroll to the edge.
    var inset: CGFloat = 20

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    let active = item == selection
                    Button {
                        Haptics.select()
                        selection = item
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: icon(item))
                                .font(.system(size: 12, weight: .bold))
                            Text(loc: title(item))
                                .font(Fonts.ui(12.5, active ? .heavy : .semibold))
                        }
                        .foregroundStyle(active ? .white : Palette.inkSoft)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(active ? Palette.amber : Palette.paper, in: Capsule())
                        .overlay(Capsule().strokeBorder(active ? Palette.ink : Palette.outlineSoft,
                                                  lineWidth: active ? 1.8 : 1.2))
                    }
                    .buttonStyle(PressableStyle(scale: 0.94))
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
            .padding(.horizontal, inset)
        }
        .scrollClipDisabled()
        .animation(Motion.snappy, value: selection)
    }
}

// MARK: - Chosen tile

/// How a picked tile shows it's picked — cover designs and page themes alike.
extension View {
    /// A chosen tile: coral ring inside an ink outline, with a tick in the corner.
    func selectedRing(_ selected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
        return self
            .overlay(shape.strokeBorder(selected ? Palette.ink : Palette.outlineSoft, lineWidth: selected ? 5 : 1.5))
            .overlay(shape.inset(by: 2).strokeBorder(selected ? Palette.amber : .clear, lineWidth: 2.5))
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(Palette.ink)
                        .frame(width: 22, height: 22)
                        .background(Palette.amber, in: RoundedRectangle(cornerRadius: Radius.badge, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.badge, style: .continuous).strokeBorder(Palette.ink, lineWidth: 1.5))
                        .padding(7)
                }
            }
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

/// The app's card: cream, a soft (or, emphasized, ink) outline, and the warm shadow. Use this
/// rather than rebuilding the background/outline/shadow by hand.
struct SoftCard: ViewModifier {
    var padding: CGFloat = 18
    var radius: CGFloat = Radius.card
    var emphasized: Bool = false          // 2px solid ink vs 1.5px soft outline
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: DesignScale.s(radius), style: .continuous)
        content
            .padding(DesignScale.s(padding))
            .background(Palette.cream, in: shape)
            .overlay(shape.strokeBorder(emphasized ? Palette.ink : Palette.outlineSoft,
                                  lineWidth: emphasized ? 2 : 1.5))
            .shadow(color: Palette.warmShadow.opacity(0.09), radius: DesignScale.s(13), x: 0, y: DesignScale.s(10))
    }
}

extension View {
    /// A settings panel: the content padded inside a soft-outlined surface.
    func panelCard() -> some View { padding(16).outlinedSurface(radius: Radius.panel) }
}

extension View {
    /// Every sheet's ground: cream, reaching under the safe areas so the system's own sheet colour
    /// never shows around it.
    func sheetBackground() -> some View { background(Palette.cream.ignoresSafeArea()) }
}

/// `panelCard()` as a container, for a panel built inline.
struct PanelCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.panelCard() }
}

/// A flat surface on a screen or sheet — rows, inputs, small panels: cream with a soft outline,
/// no shadow. `bold` gives it the ink outline instead.
struct OutlinedSurface: ViewModifier {
    var radius: CGFloat = Radius.control
    var bold = false
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(Palette.cream, in: shape)
            .overlay(shape.strokeBorder(bold ? Palette.ink : Palette.outlineSoft, lineWidth: bold ? 2 : 1.5))
    }
}

extension View {
    func outlinedSurface(radius: CGFloat = Radius.control, bold: Bool = false) -> some View {
        modifier(OutlinedSurface(radius: radius, bold: bold))
    }

    func softCard(padding: CGFloat = 18, radius: CGFloat = Radius.card, emphasized: Bool = false) -> some View {
        modifier(SoftCard(padding: padding, radius: radius, emphasized: emphasized))
    }
}

// MARK: - Icon tiles (rounded-square, black-outlined — the redesign's icon container)

/// Non-interactive icon container: cream/amber-cream fill + 2px ink border. Holds a sun, check, etc.
struct IconTile<Content: View>: View {
    var size: CGFloat = 38
    var fill: Color = Palette.iconTile
    var radius: CGFloat = Radius.tile
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .frame(width: DesignScale.s(size), height: DesignScale.s(size))
            .background(fill, in: RoundedRectangle(cornerRadius: DesignScale.s(radius), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DesignScale.s(radius), style: .continuous)
                .strokeBorder(Palette.ink, lineWidth: 2))
    }
}

/// Tappable icon tile (close / back / share / month arrows). Use the standard ones — `.back`,
/// `.close`, `.confirm` — rather than spelling out icons and sizes.
struct IconTileButton: View {
    let icon: String
    var size: CGFloat = 38
    var iconSize: CGFloat = 14
    var iconColor: Color = Palette.ink
    var fill: Color = Palette.cream
    var radius: CGFloat = Radius.tile
    var label: LocalizedStringKey? = nil
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
        .modifier(TileLabel(label: label))
    }

    /// ‹ — back out of a pushed screen.
    static func back(_ action: @escaping () -> Void) -> IconTileButton {
        IconTileButton(icon: "chevron.backward", size: 38, iconSize: 15, label: "Back", action: action)
    }

    /// ✕ — close a sheet, a page, or a cover without saving.
    static func close(_ action: @escaping () -> Void) -> IconTileButton {
        IconTileButton(icon: "xmark", size: 38, iconSize: 13, label: "Close", action: action)
    }

    /// ✓ — keep what was chosen. `highlighted` makes it coral (there's a change to keep);
    /// `enabled: false` greys the tick when there's nothing to keep yet.
    static func confirm(highlighted: Bool = false, enabled: Bool = true,
                        _ action: @escaping () -> Void) -> IconTileButton {
        IconTileButton(icon: "checkmark", size: 38, iconSize: 14,
                       iconColor: enabled ? Palette.ink : Palette.inkSofter,
                       fill: highlighted ? Palette.amber : Palette.cream,
                       label: "Done", action: action)
    }
}

/// Names a tile for VoiceOver when it has a name; otherwise the symbol's own name stays.
private struct TileLabel: ViewModifier {
    let label: LocalizedStringKey?
    @ViewBuilder func body(content: Content) -> some View {
        if let label { content.accessibilityLabel(Text(label)) } else { content }
    }
}

// MARK: - Screen header — the one header for screens and sheets

/// An optional back/close tile, the title, then trailing controls (a ✓, a switch, a sheet's ✕).
/// `.screen` titles head pushed screens; `.sheet` titles head sheets and covers.
struct ScreenHeader<Leading: View, Trailing: View>: View {
    enum Size { case screen, sheet }

    let title: Text
    var size: Size
    var leading: Leading
    var trailing: Trailing

    init(_ title: Text, size: Size = .sheet,
         @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.size = size
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            leading
            title
                .font(Fonts.display(size == .screen ? 24 : 19, .bold))
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            trailing
        }
    }
}

extension ScreenHeader where Leading == EmptyView {
    /// A sheet's header: title, then its controls (usually ✕). Call with `trailing:` spelled out.
    init(_ title: Text, size: Size = .sheet, @ViewBuilder trailing: () -> Trailing) {
        self.init(title, size: size, leading: { EmptyView() }, trailing: trailing)
    }
}

extension ScreenHeader where Leading == IconTileButton, Trailing == EmptyView {
    /// A pushed screen's header: ‹ and the title.
    init(_ title: Text, size: Size = .screen, back: @escaping () -> Void) {
        self.init(title, size: size, leading: { IconTileButton.back(back) }, trailing: { EmptyView() })
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

// MARK: - After a context menu closes

/// Runs `action` once a long-press menu has finished closing. Presenting a full-screen cover
/// while the menu is still animating away leaves it blank or stuck; deleting the pressed page
/// while its preview is still on screen lets the preview read a deleted page and crash.
@MainActor
func afterMenuCloses(_ action: @escaping @MainActor () -> Void) {
    Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(450))
        action()
    }
}

// MARK: - Empty state — the one "nothing here" screen

/// A sun, a line saying what's missing, and an optional next step. Used by the Library's search
/// and filters, an empty month book, a page that's gone, and the affirmation reader.
struct EmptyState: View {
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
                                                cornerRadius: DesignScale.s(Radius.control), ledge: 4, bordered: true))
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
