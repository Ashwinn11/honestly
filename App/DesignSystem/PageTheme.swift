import SwiftUI
import UIKit

/// Per-entry page backgrounds — the diary's "wallpapers". All drawn in code (no image assets):
/// paper textures, pastel washes, soft gradients, and scattered-symbol patterns. Every theme
/// keeps the espresso ink readable, so stored rich text needs no per-theme color rewriting.
///
/// Stored on the entry as `themeID` (the raw value); unknown/empty decodes to `.paper`, so
/// legacy entries and backups need nothing.
enum PageTheme: String, CaseIterable, Identifiable {
    // Textures
    case paper, ruled, grid, dots, kraft
    // Pastel washes
    case blush, mint, sky, lavender, butter
    // Gradients
    case sunset, dawn, dusk
    // Patterns
    case hearts, clouds, garden

    var id: String { rawValue }

    static func from(_ id: String?) -> PageTheme {
        guard let id, let theme = PageTheme(rawValue: id) else { return .paper }
        return theme
    }

    var label: String {
        switch self {
        case .paper:    return "Classic"
        case .ruled:    return "Ruled"
        case .grid:     return "Grid"
        case .dots:     return "Dotted"
        case .kraft:    return "Kraft"
        case .blush:    return "Blush"
        case .mint:     return "Mint"
        case .sky:      return "Sky"
        case .lavender: return "Lavender"
        case .butter:   return "Butter"
        case .sunset:   return "Sunset"
        case .dawn:     return "Dawn"
        case .dusk:     return "Dusk"
        case .hearts:   return "Hearts"
        case .clouds:   return "Clouds"
        case .garden:   return "Garden"
        }
    }

    /// The flat base color — what the pageCurl's `PageHost` paints behind the page (it must stay
    /// opaque; see EntryDetailView), and the fallback under gradients.
    var baseColor: Color {
        switch self {
        case .paper, .ruled, .dots: return Palette.paper
        case .grid:                 return Color(hex: "F7F6F0")
        case .kraft:                return Color(hex: "EBDFC9")
        case .blush, .hearts:       return Color(hex: "FBEDEA")
        case .mint, .garden:        return Color(hex: "EAF4E7")
        case .sky, .clouds:         return Color(hex: "E8F1FA")
        case .lavender:             return Color(hex: "F1ECF9")
        case .butter:               return Color(hex: "FCF3D9")
        case .sunset:               return Color(hex: "FFE3C5")
        case .dawn:                 return Color(hex: "FFEDDA")
        case .dusk:                 return Color(hex: "E7E9F6")
        }
    }

    var baseUIColor: UIColor { UIColor(baseColor) }

    fileprivate var gradient: [Color]? {
        switch self {
        case .sunset: return [Color(hex: "FFE7C7"), Color(hex: "FCCFC4")]
        case .dawn:   return [Color(hex: "FFEDDA"), Color(hex: "E3EFFA")]
        case .dusk:   return [Color(hex: "E4E7F6"), Color(hex: "F2ECF9")]
        default:      return nil
        }
    }

    fileprivate enum Pattern {
        case lines(vertical: Bool)
        case dots
        case symbols([String], tint: Color, opacity: Double)
    }

    fileprivate var pattern: Pattern? {
        switch self {
        case .ruled:  return .lines(vertical: false)
        case .grid:   return .lines(vertical: true)
        case .dots:   return .dots
        case .dusk:   return .symbols(["sparkle", "moon.stars.fill", "star.fill"],
                                      tint: Color(hex: "9BA5DC"), opacity: 0.28)
        case .hearts: return .symbols(["heart.fill", "heart"],
                                      tint: Color(hex: "EFA3B2"), opacity: 0.32)
        case .clouds: return .symbols(["cloud.fill", "cloud.sun.fill", "cloud"],
                                      tint: .white, opacity: 0.8)
        case .garden: return .symbols(["leaf.fill", "camera.macro", "laurel.leading"],
                                      tint: Color(hex: "7FB287"), opacity: 0.3)
        default:      return nil
        }
    }
}

// MARK: - The background itself — drop-in replacement for `PaperBackground`, themed

struct PageThemeBackground: View {
    let theme: PageTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            base
                .colorEffect(ShaderLibrary.grain(.float(reduceMotion ? 0 : 0.045)))
            patternLayer
        }
        .ignoresSafeArea()
    }

    @ViewBuilder private var base: some View {
        if let colors = theme.gradient {
            Rectangle().fill(LinearGradient(colors: colors,
                                            startPoint: .top, endPoint: .bottom))
        } else {
            Rectangle().fill(theme.baseColor)
        }
    }

    @ViewBuilder private var patternLayer: some View {
        switch theme.pattern {
        case .lines(let vertical):
            LinePattern(vertical: vertical)
        case .dots:
            DotPattern()
        case .symbols(let symbols, let tint, let opacity):
            SymbolScatter(symbols: symbols, tint: tint, symbolOpacity: opacity)
        case nil:
            EmptyView()
        }
    }
}

// MARK: - Pattern layers (all Canvas — cheap, resolution-independent, no assets)

private struct LinePattern: View {
    let vertical: Bool
    var spacing: CGFloat = 26
    var body: some View {
        Canvas { context, size in
            var path = Path()
            var y = spacing
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            if vertical {
                var x = spacing
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += spacing
                }
            }
            context.stroke(path, with: .color(Palette.ink.opacity(0.06)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

private struct DotPattern: View {
    var spacing: CGFloat = 22
    var body: some View {
        Canvas { context, size in
            var path = Path()
            var y = spacing
            while y < size.height {
                var x = spacing
                while x < size.width {
                    path.addEllipse(in: CGRect(x: x - 1.1, y: y - 1.1, width: 2.2, height: 2.2))
                    x += spacing
                }
                y += spacing
            }
            context.fill(path, with: .color(Palette.ink.opacity(0.13)))
        }
        .allowsHitTesting(false)
    }
}

/// Scattered tinted SF Symbols — the "cute wallpaper" layer. Deterministic (seeded) so the
/// pattern never shimmers between renders; staggered grid + jitter + rotation so it doesn't
/// read as a grid.
private struct SymbolScatter: View {
    let symbols: [String]
    let tint: Color
    let symbolOpacity: Double
    var spacing: CGFloat = 88

    var body: some View {
        Canvas { context, size in
            var rng = SeededRandom(seed: 9)
            let columns = Int(size.width / spacing) + 2
            let rows = Int(size.height / spacing) + 2
            for row in 0..<rows {
                for column in 0..<columns {
                    let stagger: CGFloat = row.isMultiple(of: 2) ? 0 : spacing / 2
                    let x = CGFloat(column) * spacing + stagger + rng.jitter(spacing * 0.36)
                    let y = CGFloat(row) * spacing + rng.jitter(spacing * 0.36)
                    let side = 13 + rng.unit() * 12
                    let rotation = Angle.degrees((rng.unit() - 0.5) * 40)

                    var resolved = context.resolve(Image(systemName: symbols[rng.pick(symbols.count)]))
                    resolved.shading = .color(tint)
                    context.drawLayer { layer in
                        layer.opacity = symbolOpacity
                        layer.translateBy(x: x, y: y)
                        layer.rotate(by: rotation)
                        layer.draw(resolved, in: CGRect(x: -side / 2, y: -side / 2, width: side, height: side))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Tiny deterministic LCG — just enough randomness for wallpaper jitter, stable across renders.
private struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func unit() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) & 0xFFFFFF) / CGFloat(0xFFFFFF)
    }
    mutating func jitter(_ magnitude: CGFloat) -> CGFloat { (unit() - 0.5) * 2 * magnitude }
    mutating func pick(_ count: Int) -> Int { Int(unit() * CGFloat(count)) % max(count, 1) }
}

// MARK: - Picker sheet — theme cards in a grid, tap to apply (live behind the editor)

struct ThemePickerSheet: View {
    @Binding var selection: PageTheme
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(loc: "Page theme")
                    .font(Fonts.display(19, .bold)).foregroundStyle(Palette.ink)
                Spacer()
                IconTileButton(icon: "xmark", size: 34, iconSize: 12) { dismiss() }
            }
            .padding(EdgeInsets(top: 18, leading: 20, bottom: 6, trailing: 20))

            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(PageTheme.allCases) { theme in
                        themeCard(theme)
                    }
                }
                .padding(20)
            }
        }
        .background(Palette.cream)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    private func themeCard(_ theme: PageTheme) -> some View {
        let selected = theme == selection
        return Button {
            Haptics.select()
            selection = theme
        } label: {
            VStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.clear)
                    .frame(height: 108)
                    .overlay {
                        PageThemeBackground(theme: theme)
                            // A mini page: same drawing, just clipped — ignoresSafeArea inside
                            // is neutralized by the clip.
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(selected ? Palette.amber : Palette.outlineSoft, lineWidth: selected ? 2.5 : 1.5))
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white, Palette.amber)
                                .padding(6)
                        }
                    }
                Text(loc: theme.label)
                    .font(Fonts.ui(12, selected ? .heavy : .semibold))
                    .foregroundStyle(selected ? Palette.ink : Palette.inkSoft)
            }
        }
        .buttonStyle(PressableStyle(scale: 0.96))
    }
}
