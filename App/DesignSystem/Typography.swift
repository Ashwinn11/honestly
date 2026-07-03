import SwiftUI

/// Two-family type system, mirroring the prototype:
/// • **Shantell Sans** — the warm handwritten display face (titles, greetings, big numbers).
/// • **Nunito** — the rounded UI/body sans (labels, buttons, body copy, eyebrows).
///
/// Both are bundled as static per-weight instances (see `App/Resources/Fonts`) and addressed
/// by PostScript name so the exact design weight always renders. Sizes are fixed to match the
/// prototype's pixel values 1:1.
enum Fonts {

    /// Shantell Sans — display / handwritten headings.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .custom(shantell(weight), fixedSize: size)
    }

    /// Nunito — UI, body, labels.
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .custom(nunito(weight), fixedSize: size)
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
