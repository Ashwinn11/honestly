import SwiftUI

enum DesignScale {
    static let reference: CGFloat = 393
    static let maxFactor: CGFloat = 1.45

    private(set) static var factor: CGFloat = 1.0

    static func configure(width: CGFloat) {
        factor = min(max(width / reference, 1.0), maxFactor)
    }
    static func s(_ v: CGFloat) -> CGFloat { v * factor }
}

enum Metrics {
    static var maxContentWidth: CGFloat { DesignScale.s(430) }
    static let maxButtonWidth: CGFloat = 430

    /// The page's left/right margin — shared by every place that renders the journal "page"
    /// (writing in RitualView, editing in EntryEditorView, reading in EntryDetailView's
    /// JournalReaderPage). These three used to each hand-roll their own `EdgeInsets`, and two of
    /// them silently drifted from the third (`trailing: 20` vs `22`) — a couple points that don't
    /// matter for text, but do matter for an attachment saved at "full width": its stored bounds
    /// are computed from whichever container happened to be showing it, so any inset mismatch
    /// between write/edit and read makes a full-bleed photo/doodle look not-quite-full-bleed (or
    /// scaled differently) depending on which of the three screens is displaying it. One constant
    /// here means that class of bug can't come back by accident.
    static let pageHorizontalInset: CGFloat = 22
}

/// Corner radii — the only ones the app uses. Pick by what the shape is, not by eye.
enum Radius {
    static let badge: CGFloat = 7       // ticks and tiny badges
    static let tile: CGFloat = 11       // icon tiles and compact controls
    static let chip: CGFloat = 12       // segmented switches, small buttons
    static let control: CGFloat = 14    // rows, inputs, tiles in a grid, primary buttons
    static let panel: CGFloat = 18      // cards inside sheets, tips
    static let card: CGFloat = 22       // cards on a screen
    static let hero: CGFloat = 24       // the large feature card on a screen
}

extension View {
    func capWidth(_ max: CGFloat) -> some View {
        frame(maxWidth: max).frame(maxWidth: .infinity)
    }
}

/// Single-family type system built around **Manrope** — a clean geometric sans that works
/// across display headlines, UI labels, buttons, and body copy.
///
/// Manrope ships as a variable font (`Manrope.ttf`) bundled in `App/Resources/Fonts`.
/// iOS registers named instances per weight (Manrope-Regular, Manrope-Medium, etc.),
/// addressed by PostScript name so the exact design weight always renders. Base sizes match
/// the prototype 1:1; every size is multiplied by `DesignScale.factor` so text is responsive
/// across devices.
enum Fonts {

    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .custom(manrope(weight), fixedSize: DesignScale.s(size))
    }

    static func ui(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .custom(manrope(weight), fixedSize: DesignScale.s(size))
    }

    private static func manrope(_ w: Font.Weight) -> String {
        switch w {
        case .ultraLight, .thin, .light, .regular: return "Manrope-Regular"
        case .medium:                              return "Manrope-Medium"
        case .semibold:                            return "Manrope-SemiBold"
        case .bold:                                return "Manrope-Bold"
        default:                                   return "Manrope-ExtraBold" // heavy/black
        }
    }
}

// MARK: - Text conveniences

extension Text {
    func display(_ size: CGFloat, _ weight: Font.Weight = .bold, color: Color = Palette.ink) -> Text {
        self.font(Fonts.display(size, weight)).foregroundColor(color)
    }
    func ui(_ size: CGFloat, _ weight: Font.Weight = .bold, color: Color = Palette.ink) -> Text {
        self.font(Fonts.ui(size, weight)).foregroundColor(color)
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = Palette.inkSofter
    var tracking: CGFloat = 1.4
    var size: CGFloat = 11.5
    var body: some View {
        Text(loc: text)                       // localize the source label, then uppercase for display
            .textCase(.uppercase)
            .font(Fonts.ui(size, .heavy))
            .tracking(tracking)
            .foregroundStyle(color)
    }
}
