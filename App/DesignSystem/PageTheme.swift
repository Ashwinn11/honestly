import SwiftUI
import UIKit

/// Per-entry page backgrounds — the diary's "wallpapers". All drawn in code (no image assets):
/// paper textures, pastel washes, soft gradients, and scattered-symbol patterns. Every theme
/// keeps the espresso ink readable, so stored rich text needs no per-theme color rewriting —
/// even the moodier families (dark academia, celestial) stay light-washed, leaning on darker
/// accent motifs rather than a true dark background, to preserve that.
///
/// Stored on the entry as `themeID` (the raw value); unknown/empty decodes to `.paper`, so
/// legacy entries and backups need nothing.
enum PageTheme: String, CaseIterable, Identifiable {
    // Plain basics
    case paper, grid, dots
    // Quiet luxury
    case linen, ledger
    // Cottagecore
    case meadow, mushroomWood
    // Dark academia
    case library, inkGold
    // Celestial
    case midnight, stargazer
    // Coastal
    case tide, seaGlass
    // Coquette
    case ballet, cherry
    // Kawaii
    case sunshine, bubblegum

    var id: String { rawValue }

    static func from(_ id: String?) -> PageTheme {
        guard let id, let theme = PageTheme(rawValue: id) else { return .paper }
        return theme
    }

    var label: String {
        switch self {
        case .paper:        return "Classic"
        case .grid:         return "Grid"
        case .dots:         return "Dotted"
        case .linen:        return "Linen"
        case .ledger:       return "Ledger"
        case .meadow:       return "Meadow"
        case .mushroomWood: return "Mushroom Wood"
        case .library:      return "Library"
        case .inkGold:      return "Ink & Gold"
        case .midnight:     return "Midnight"
        case .stargazer:    return "Stargazer"
        case .tide:         return "Tide"
        case .seaGlass:     return "Sea Glass"
        case .ballet:       return "Ballet"
        case .cherry:       return "Cherry"
        case .sunshine:     return "Sunshine"
        case .bubblegum:    return "Bubblegum"
        }
    }

    /// The flat base color — what the pageCurl's `PageHost` paints behind the page (it must stay
    /// opaque; see EntryDetailView), and the fallback under gradients.
    var baseColor: Color {
        switch self {
        case .paper:        return Palette.paper
        case .grid:         return Color(hex: "F7F6F0")
        case .dots:         return Palette.paper
        case .linen:        return Color(hex: "F1ECE1")
        case .ledger:       return Color(hex: "F2F4F7")
        case .meadow:       return Color(hex: "EEF3E6")
        case .mushroomWood: return Color(hex: "EDE1CD")
        case .library:      return Color(hex: "F1E6CE")
        case .inkGold:      return Color(hex: "F6F1E3")
        case .midnight:     return Color(hex: "E4E7F7")
        case .stargazer:    return Color(hex: "E7E9F0")
        case .tide:         return Color(hex: "E2EFF3")
        case .seaGlass:     return Color(hex: "E7F2EE")
        case .ballet:       return Color(hex: "FBEDEE")
        case .cherry:       return Color(hex: "FCEAE8")
        case .sunshine:     return Color(hex: "FCF3D9")
        case .bubblegum:    return Color(hex: "FBEAF4")
        }
    }

    var baseUIColor: UIColor { UIColor(baseColor) }

    fileprivate var gradient: [Color]? {
        switch self {
        case .inkGold:   return [Color(hex: "F8F2E2"), Color(hex: "EDE7D2")]
        case .midnight:  return [Color(hex: "E4E7F7"), Color(hex: "EFEAF9")]
        case .tide:      return [Color(hex: "DDEEF4"), Color(hex: "EAF5EF")]
        default:         return nil
        }
    }

    fileprivate enum Pattern {
        case lines(vertical: Bool, tint: Color, spacing: CGFloat)
        case dots(tint: Color, spacing: CGFloat)
        case waves(tint: Color)
        case symbols([String], tint: Color, opacity: Double, spacing: CGFloat)
    }

    fileprivate var pattern: Pattern? {
        switch self {
        case .grid:
            return .lines(vertical: true, tint: Palette.ink.opacity(0.06), spacing: 26)
        case .dots:
            return .dots(tint: Palette.ink.opacity(0.13), spacing: 22)
        case .linen:
            // Barely-there micro-stripe — "quiet luxury" texture felt more than seen.
            return .lines(vertical: false, tint: Color(hex: "8A7A67").opacity(0.10), spacing: 8)
        case .ledger:
            return .lines(vertical: false, tint: Color(hex: "5C6B7A").opacity(0.18), spacing: 26)
        case .meadow:
            return .symbols(["leaf.fill", "laurel.leading"], tint: Color(hex: "6E9A5E"),
                            opacity: 0.3, spacing: 82)
        case .mushroomWood:
            return .symbols(["leaf.fill", "circle.fill"], tint: Color(hex: "B5654A"),
                            opacity: 0.26, spacing: 78)
        case .library:
            return .symbols(["book.closed.fill", "bookmark.fill", "laurel.leading"],
                            tint: Color(hex: "7A3B32"), opacity: 0.22, spacing: 92)
        case .inkGold:
            return .symbols(["sparkle", "star.fill"], tint: Color(hex: "B8903F"),
                            opacity: 0.32, spacing: 86)
        case .midnight:
            return .symbols(["moon.stars.fill", "star.fill", "sparkle"], tint: Color(hex: "6A6FA8"),
                            opacity: 0.3, spacing: 88)
        case .stargazer:
            // Denser, cooler-tinted scatter than Midnight — same light base, more dramatic.
            return .symbols(["star.fill", "sparkle", "star"], tint: Color(hex: "4C5578"),
                            opacity: 0.36, spacing: 62)
        case .tide:
            return .waves(tint: Color(hex: "6FA6B8").opacity(0.32))
        case .ballet:
            return .symbols(["heart.fill", "sparkle", "circle.fill"], tint: Color(hex: "E9A6B3"),
                            opacity: 0.3, spacing: 78)
        case .cherry:
            return .symbols(["heart.fill", "heart"], tint: Color(hex: "C4453F"),
                            opacity: 0.3, spacing: 70)
        case .sunshine:
            return .symbols(["cloud.fill", "sun.max.fill", "cloud"], tint: Color(hex: "E3A94A"),
                            opacity: 0.28, spacing: 86)
        case .bubblegum:
            return .symbols(["star.fill", "sparkle", "circle.fill"], tint: Color(hex: "C77BB0"),
                            opacity: 0.3, spacing: 74)
        case .paper, .seaGlass:
            return nil   // flat washes — texture comes purely from color
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
        case .lines(let vertical, let tint, let spacing):
            LinePattern(vertical: vertical, tint: tint, spacing: spacing)
        case .dots(let tint, let spacing):
            DotPattern(tint: tint, spacing: spacing)
        case .waves(let tint):
            WavePattern(tint: tint)
        case .symbols(let symbols, let tint, let opacity, let spacing):
            SymbolScatter(symbols: symbols, tint: tint, symbolOpacity: opacity, spacing: spacing)
        case nil:
            EmptyView()
        }
    }
}

// MARK: - Pattern layers (all Canvas — cheap, resolution-independent, no assets)

private struct LinePattern: View {
    let vertical: Bool
    var tint: Color = Palette.ink.opacity(0.06)
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
            context.stroke(path, with: .color(tint), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

private struct DotPattern: View {
    var tint: Color = Palette.ink.opacity(0.13)
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
            context.fill(path, with: .color(tint))
        }
        .allowsHitTesting(false)
    }
}

/// Repeating horizontal sine-wave rows — the "Tide" theme's water texture.
private struct WavePattern: View {
    let tint: Color
    var amplitude: CGFloat = 4
    var wavelength: CGFloat = 46
    var rowSpacing: CGFloat = 28
    var body: some View {
        Canvas { context, size in
            var path = Path()
            var y = rowSpacing
            while y < size.height {
                var x: CGFloat = 0
                var first = true
                while x <= size.width {
                    let point = CGPoint(x: x, y: y + sin(x / wavelength * .pi * 2) * amplitude)
                    if first { path.move(to: point); first = false } else { path.addLine(to: point) }
                    x += 4
                }
                y += rowSpacing
            }
            context.stroke(path, with: .color(tint), lineWidth: 1.2)
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
    @Environment(PremiumManager.self) private var premium
    @Environment(AppFlow.self) private var flow

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
        // Browsing the grid is free; picking a theme you don't already have is the premium
        // action — the theme you're already on never shows a lock, since re-selecting it is a
        // no-op either way.
        let locked = !premium.isPremium && !selected
        return Button {
            if locked {
                flow.showPaywall()
                return
            }
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
                        } else if locked {
                            lockBadge.padding(6)
                        }
                    }
                Text(loc: theme.label)
                    .font(Fonts.ui(12, selected ? .heavy : .semibold))
                    .foregroundStyle(selected ? Palette.ink : Palette.inkSoft)
            }
        }
        .buttonStyle(PressableStyle(scale: 0.96))
    }

    private var lockBadge: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 17, height: 17)
            .background(Palette.amber, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 1))
    }
}
