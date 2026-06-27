import SwiftUI

// MARK: - Design System
// Strict tokens for Honestly. "Soft neo-brutalist": warm cream surfaces,
// thick black outlines, hard offset shadows, handwriting accent over a clean sans.

enum Theme {

    // MARK: Colors
    static let bg        = Color(hex: "#F7F5F0")   // page background
    static let card      = Color(hex: "#FFFEF9")   // card surface
    static let paper     = Color(hex: "#FBF9F3")   // lined-paper journal surface
    static let ink       = Color(hex: "#1C1C1C")   // text + ALL borders
    static let inkFaint  = Color(hex: "#1C1C1C").opacity(0.45)
    static let inkGhost  = Color(hex: "#1C1C1C").opacity(0.12)
    static let orange    = Color(hex: "#FF6B00")   // primary CTA / accent
    static let dark      = Color(hex: "#2D2D2D")   // secondary dark button

    // Mood
    static let happy     = Color(hex: "#FEAE5E")
    static let confused  = Color(hex: "#D1E4A5")
    static let sad       = Color(hex: "#FBABA6")
    static let awful     = Color(hex: "#FE526C")
    static let cry       = Color(hex: "#A8C8E8")

    // Misc
    static let blush     = Color(hex: "#FBABA6").opacity(0.6)
    static let gratitude = Color(hex: "#FAD8D6")   // pink gratitude card

    // MARK: Shape & elevation
    static let cardRadius: CGFloat   = 24
    static let borderWidth: CGFloat  = 2.5
    static let shadowOffset: CGFloat = 5            // hard, solid offset (blur 0)

    // Peach radial wash for page backgrounds
    static var pageBackground: some View {
        ZStack {
            bg
            RadialGradient(
                colors: [happy.opacity(0.18), .clear],
                center: .topLeading, startRadius: 0, endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Typography

/// Fonts are referenced by exact PostScript face name (no `.weight()` synthesis),
/// because the static LTSaeada/Caveat weights ship as separate font families.
enum AppFont {
    // PostScript faces (registered via UIAppFonts in the app + widget targets).
    private static func ltSaeada(_ weight: Font.Weight) -> String {
        switch weight {
        case .medium:                   return "LTSaeada-Medium"
        case .semibold:                 return "LTSaeada-SemiBold"
        case .bold, .heavy, .black:     return "LTSaeada-Bold"
        default:                        return "LTSaeada-Regular"
        }
    }
    private static func caveat(_ weight: Font.Weight) -> String {
        switch weight {
        case .medium:   return "Caveat-Medium"
        case .semibold: return "Caveat-SemiBold"
        case .bold:     return "Caveat-Bold"
        default:        return "Caveat-Regular"
        }
    }

    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(ltSaeada(weight), size: size)
    }
    static func script(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(caveat(weight), size: size)
    }

    // Semantic styles
    static func display(_ size: CGFloat = 34) -> Font { sans(size, .bold) }
    static func title(_ size: CGFloat = 34)   -> Font { sans(size, .bold) }
    static func cardTitle(_ size: CGFloat = 26) -> Font { sans(size, .bold) }
    static func body(_ size: CGFloat = 16)    -> Font { sans(size, .regular) }
    static func bodyMedium(_ size: CGFloat = 16) -> Font { sans(size, .medium) }
    static func bodySemibold(_ size: CGFloat = 16) -> Font { sans(size, .semibold) }
    static func bodyBold(_ size: CGFloat = 16) -> Font { sans(size, .bold) }
    static func button(_ size: CGFloat = 17)  -> Font { sans(size, .bold) }
    static func caption(_ size: CGFloat = 13) -> Font { sans(size, .medium) }
    static func captionBold(_ size: CGFloat = 13) -> Font { sans(size, .bold) }

    static func eyebrow(_ size: CGFloat = 20) -> Font { script(size, .semibold) }
    static func accent(_ size: CGFloat = 18)  -> Font { script(size, .medium) }
}

// MARK: - View modifiers

extension View {
    /// Thick-border card with a hard offset shadow BELOW — the signature surface.
    /// An opaque base sits under `fill` so translucent tints (e.g. selected state)
    /// can't let the black shadow bleed through the whole card (which read as a
    /// shadow on the wrong side).
    func appCardStyle(radius: CGFloat = Theme.cardRadius,
                      fill: Color = Theme.card,
                      borderColor: Color = Theme.ink) -> some View {
        self
            .background(fill)                       // tint directly behind content
            .background(Theme.card)                 // opaque base blocks shadow bleed
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(borderColor, lineWidth: Theme.borderWidth)
            )
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.ink)
                    .offset(y: Theme.shadowOffset)  // +y = below
            )
    }
}

// MARK: - Color hex init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:  (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (0, 0, 0)
        }
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
