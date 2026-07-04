import SwiftUI

/// Global responsive scale. `1.0` on iPhone; grows on wider screens (iPad) so type, components,
/// and spacing scale up together instead of leaving a tiny phone UI centered in a big window.
/// Set once at launch via `configure(width:)` — the app is portrait-locked and full-screen, so the
/// width is stable. Everything responsive runs through `s(_:)` or the scaled `Fonts`/`Layout`.
enum DesignScale {
    /// iPhone reference width the prototype was designed against.
    static let reference: CGFloat = 393
    /// Ceiling so an iPad doesn't scale absurdly large. Tune this one value to taste.
    static let maxFactor: CGFloat = 1.30

    private(set) static var factor: CGFloat = 1.0

    static func configure(width: CGFloat) {
        factor = min(max(width / reference, 1.0), maxFactor)
    }
    /// Scale a design value (padding, size, radius) by the current factor.
    static func s(_ v: CGFloat) -> CGFloat { v * factor }
}

/// Responsive width caps. Fluid *below* the cap (so they're no-ops on iPhone) and centered *above*
/// it (so iPad content sits in a column, not edge-to-edge). Backgrounds stay full-bleed separately.
/// (Named `Metrics`, not `Layout`, to avoid colliding with SwiftUI's `Layout` protocol.)
enum Metrics {
    /// The centered content column — scales with the design factor so the scaled UI fits it.
    static var maxContentWidth: CGFloat { DesignScale.s(430) }
    /// CTA cap — deliberately *narrower* than the column and NOT scaled, so buttons never span the
    /// whole column on iPad (≥ any phone's button width, so it's a no-op on iPhone).
    static let maxButtonWidth: CGFloat = 430
}

extension View {
    /// Cap width to a centered column, fluid below the cap.
    func capWidth(_ max: CGFloat) -> some View {
        frame(maxWidth: max).frame(maxWidth: .infinity)
    }
}

/// Two-family type system, mirroring the prototype:
/// • **Shantell Sans** — the warm handwritten display face (titles, greetings, big numbers).
/// • **Nunito** — the rounded UI/body sans (labels, buttons, body copy, eyebrows).
///
/// Both are bundled as static per-weight instances (see `App/Resources/Fonts`) and addressed
/// by PostScript name so the exact design weight always renders. Base sizes match the prototype
/// 1:1; every size is multiplied by `DesignScale.factor` so text is responsive across devices.
enum Fonts {

    /// Shantell Sans — display / handwritten headings.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .custom(shantell(weight), fixedSize: DesignScale.s(size))
    }

    /// Nunito — UI, body, labels.
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .custom(nunito(weight), fixedSize: DesignScale.s(size))
    }

    private static func nunito(_ w: Font.Weight) -> String {
        switch w {
        case .ultraLight, .thin, .light, .regular: return "Nunito-Regular"
        case .medium:                              return "Nunito-Medium"
        case .semibold:                            return "Nunito-SemiBold"
        case .bold:                                return "Nunito-Bold"
        case .heavy:                               return "Nunito-ExtraBold"
        default:                                   return "Nunito-Black"        // .black
        }
    }

    private static func shantell(_ w: Font.Weight) -> String {
        switch w {
        case .ultraLight, .thin, .light, .regular, .medium: return "ShantellSans-Medium"
        case .semibold:                                     return "ShantellSans-SemiBold"
        case .bold:                                         return "ShantellSans-Bold"
        default:                                            return "ShantellSans-ExtraBold" // heavy/black
        }
    }
}

// MARK: - Text conveniences

extension Text {
    /// Shantell display heading in ink.
    func display(_ size: CGFloat, _ weight: Font.Weight = .bold, color: Color = Palette.ink) -> Text {
        self.font(Fonts.display(size, weight)).foregroundColor(color)
    }
    /// Nunito UI text.
    func ui(_ size: CGFloat, _ weight: Font.Weight = .bold, color: Color = Palette.ink) -> Text {
        self.font(Fonts.ui(size, weight)).foregroundColor(color)
    }
}

/// The uppercase, letter-spaced eyebrow used above cards and sections throughout the app.
struct Eyebrow: View {
    let text: String
    var color: Color = Palette.inkSofter
    var tracking: CGFloat = 1.4
    var size: CGFloat = 11.5
    var body: some View {
        Text(text.uppercased())
            .font(Fonts.ui(size, .heavy))
            .tracking(tracking)
            .foregroundStyle(color)
    }
}
