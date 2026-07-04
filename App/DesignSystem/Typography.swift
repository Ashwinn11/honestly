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
}

extension View {
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

    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .custom(shantell(weight), fixedSize: DesignScale.s(size))
    }

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
        Text(text.uppercased())
            .font(Fonts.ui(size, .heavy))
            .tracking(tracking)
            .foregroundStyle(color)
    }
}
