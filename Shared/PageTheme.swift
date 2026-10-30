import SwiftUI
import UIKit

/// Per-entry page backgrounds — the diary's "wallpapers" — shared by the journal and the
/// affirmation widget: 35 themes, each its own drawing, all in code (no image assets).
///
/// Entries store the default espresso ink on their text, so no theme rewrites anything: the page
/// swaps that default ink for `ink` as it draws (see `PageInkLayoutManager`), and colours the
/// writer picked stay as picked.
///
/// Stored on the entry as `themeID` (the raw value). Unknown or empty decodes to `.paper`, and a
/// retired theme to the one closest to it, so older entries, backups, covers and widgets need nothing.
enum PageTheme: String, CaseIterable, Identifiable {
    // Paper
    case paper, dots, grid, linen, kraft, watercolor, library
    // Airy
    case sage, sunrise, sunshine, clouds, tide, riso
    // Scattered
    case laurel, midnight, ballet, cherry, stargazer, candy, forest
    // Prints
    case meadow, garden, hearts, bows, wildflowers, inkGold, bubblegum, gingham
    // Dark
    case nightSky, aurora, ember, noir, velvet, blueprint, pine

    var id: String { rawValue }

    /// Themes no longer offered, each sent to the closest one that is.
    private static let retired: [String: PageTheme] = [
        "ledger": .grid, "mushroomWood": .kraft, "seaGlass": .tide, "botanical": .laurel, "terrazzo": .riso,
    ]

    static func from(_ id: String?) -> PageTheme {
        guard let id else { return .paper }
        return PageTheme(rawValue: id) ?? retired[id] ?? .paper
    }

    /// The themes anyone can write on, one from each group; the rest come with Premium.
    static let free: Set<PageTheme> = [.paper, .sunshine, .laurel, .meadow, .nightSky]
    var isFree: Bool { Self.free.contains(self) }

    /// How the picker groups the themes.
    enum Group: String, CaseIterable {
        case paper = "Paper", airy = "Airy", scattered = "Scattered", prints = "Prints", dark = "Dark"

        var icon: String {
            switch self {
            case .paper: "doc"
            case .airy: "cloud"
            case .scattered: "sparkles"
            case .prints: "square.grid.2x2"
            case .dark: "moon.stars"
            }
        }
    }

    var group: Group {
        switch self {
        case .paper, .dots, .grid, .linen, .kraft, .watercolor, .library:                    return .paper
        case .sage, .sunrise, .sunshine, .clouds, .tide, .riso:                              return .airy
        case .laurel, .midnight, .ballet, .cherry, .stargazer, .candy, .forest:              return .scattered
        case .meadow, .garden, .hearts, .bows, .wildflowers, .inkGold, .bubblegum, .gingham: return .prints
        case .nightSky, .aurora, .ember, .noir, .velvet, .blueprint, .pine:                  return .dark
        }
    }

    var label: String {
        switch self {
        case .paper:       return "Classic"
        case .dots:        return "Dotted"
        case .grid:        return "Graph"
        case .linen:       return "Linen"
        case .kraft:       return "Kraft"
        case .watercolor:  return "Watercolor"
        case .library:     return "Library"
        case .sage:        return "Sage"
        case .sunrise:     return "Sunrise"
        case .sunshine:    return "Sunshine"
        case .clouds:      return "Clouds"
        case .tide:        return "Tide"
        case .riso:        return "Riso"
        case .laurel:      return "Laurel"
        case .midnight:    return "Midnight"
        case .ballet:      return "Ballet"
        case .cherry:      return "Cherry"
        case .stargazer:   return "Stargazer"
        case .candy:       return "Candy"
        case .forest:      return "Forest"
        case .meadow:      return "Meadow"
        case .garden:      return "Garden"
        case .hearts:      return "Hearts"
        case .bows:        return "Bows"
        case .wildflowers: return "Wildflowers"
        case .inkGold:     return "Gilded"
        case .bubblegum:   return "Bubblegum"
        case .gingham:     return "Gingham"
        case .nightSky:    return "Moonlit"
        case .aurora:      return "Aurora"
        case .ember:       return "Ember"
        case .noir:        return "Noir"
        case .velvet:      return "Velvet"
        case .blueprint:   return "Blueprint"
        case .pine:        return "Pine"
        }
    }

    /// The page colour, the ink written on it, and the softer ink of its date and hints.
    private var palette: (page: String, ink: String, soft: String) {
        switch self {
        case .paper:       return ("FAF8F5", "33261A", "8A7A67")
        case .dots:        return ("FBF9F4", "33261A", "8A7A67")
        case .grid:        return ("EEF4EA", "2F3A2C", "637A5E")
        case .linen:       return ("F1EBDF", "33261A", "8A7A67")
        case .kraft:       return ("CDAE84", "2E2116", "5E4527")
        case .watercolor:  return ("FBF8F2", "33261A", "8A7A67")
        case .library:     return ("EEE1C4", "3A2A1C", "7D6246")
        case .sage:        return ("E6ECE0", "2C3427", "66745E")
        case .sunrise:     return ("FFD8BE", "3A2416", "8C5A3C")
        case .sunshine:    return ("FFF6DB", "3A2E12", "8E7330")
        case .clouds:      return ("E3F0FB", "1F3042", "5A7690")
        case .tide:        return ("E4EFF4", "22333B", "5B7480")
        case .riso:        return ("FFF5EC", "33221C", "A05A66")
        case .laurel:      return ("EEF3E6", "2C3427", "66745E")
        case .midnight:    return ("E4E7F7", "2B2E4A", "6E7196")
        case .ballet:      return ("FBEDEE", "3A2229", "A0636F")
        case .cherry:      return ("FCEAE8", "3A1F1C", "A0605A")
        case .stargazer:   return ("E7E9F0", "262B3D", "5F6680")
        case .candy:       return ("FBEAF4", "3A2233", "A05F84")
        case .forest:      return ("182F22", "EEF3EC", "A9BFAF")
        case .meadow:      return ("EEF3E6", "2C3427", "66745E")
        case .garden:      return ("EEF3E6", "33261A", "8A7A67")
        case .hearts:      return ("FCEEF0", "3A2229", "A0636F")
        case .bows:        return ("FBE9EF", "3A2229", "A0636F")
        case .wildflowers: return ("FBF6EC", "33261A", "8A7A67")
        case .inkGold:     return ("F6F1E3", "2F2A24", "8C7550")
        case .bubblegum:   return ("FDF0F6", "3A2233", "A05F84")
        case .gingham:     return ("FFFCFA", "33221C", "A0605A")
        case .nightSky:    return ("0F1B3C", "F6F1E8", "B9C2DC")
        case .aurora:      return ("0C1822", "F2F7F5", "A9C6C2")
        case .ember:       return ("1B1310", "FBEFE4", "D9B49A")
        case .noir:        return ("14120F", "F3EBDD", "C9A45C")
        case .velvet:      return ("2A1230", "F7ECF6", "D4B8D6")
        case .blueprint:   return ("1C4682", "EEF4FF", "B7C9E6")
        case .pine:        return ("12271D", "EEF3EC", "A9BFAF")
        }
    }

    /// The page's single colour — what shows behind a page mid-curl, and the widget's background
    /// when a gradient can't be used.
    var baseColor: Color { Color(hex: palette.page) }

    var baseUIColor: UIColor { UIColor(baseColor) }

    /// Light ink on the dark pages; a tinted espresso everywhere else.
    var isDark: Bool {
        switch self {
        case .forest, .nightSky, .aurora, .ember, .noir, .velvet, .blueprint, .pine: return true
        default: return false
        }
    }

    /// The ink entries and the widget store their text in.
    static let defaultInkHex = "33261A"

    /// The hex of `ink` — the widget's text colour on this theme unless one was picked.
    var inkHex: String { palette.ink }

    var ink: Color { Color(hex: inkHex) }
    var inkUI: UIColor { UIColor(hex: inkHex) }
    var inkSoft: Color { Color(hex: palette.soft) }

    /// Whether this page draws the default ink in an ink of its own.
    var tintsInk: Bool { inkHex != Self.defaultInkHex }

    /// The widget's text colour: the theme's ink while the default ink is still chosen, so a dark
    /// theme never ends up with dark text; a colour the user picked always wins.
    func widgetTextHex(chosen: String) -> String {
        chosen.uppercased() == Self.defaultInkHex ? inkHex : chosen
    }

    /// Room above the page's header for scenery hanging across the top of the page.
    var headerClearance: CGFloat { self == .bows ? 36 : 0 }

    enum Backdrop {
        case flat(Color)
        case linear([Gradient.Stop])                                          // top to bottom
        case elliptical([Gradient.Stop], center: UnitPoint, radius: CGFloat)  // radius as a fraction of the page
    }

    var backdrop: Backdrop {
        func fade(_ top: String, _ bottom: String) -> Backdrop {
            .linear(Gradient(colors: [Color(hex: top), Color(hex: bottom)]).stops)
        }
        switch self {
        case .sunrise:
            return .linear([.init(color: Color(hex: "FFE4CF"), location: 0), .init(color: Color(hex: "FFC6A6"), location: 0.55),
                            .init(color: Color(hex: "FFD99C"), location: 1)])
        case .sunshine:  return fade("FFF0C7", "FFFBF0")
        case .clouds:    return fade("D6EAFA", "F2F8FE")
        case .tide:      return fade("DDEDF4", "ECF6F0")
        case .midnight:  return fade("E4E7F7", "EFEAF9")
        case .forest:    return fade("12241A", "1F3B2B")
        case .inkGold:   return fade("F8F2E2", "EDE6D0")
        case .nightSky:  return fade("0B1631", "1B2D5A")
        case .aurora:    return fade("0A1520", "101C2E")
        case .ember:     return fade("181110", "291611")
        case .velvet:
            return .elliptical([.init(color: Color(hex: "57295F"), location: 0), .init(color: Color(hex: "2A1230"), location: 0.6),
                                .init(color: Color(hex: "170A1B"), location: 1)],
                               center: UnitPoint(x: 0.5, y: 0.32), radius: 0.8)
        case .blueprint: return fade("1F4E8D", "173C70")
        case .pine:      return fade("0D1F17", "1B3627")
        default:         return .flat(baseColor)
        }
    }
}

/// What a theme is drawn on. A page runs under the status bar and carries its header across the
/// top, so scenery pinned there (a moon, a sun, a garland) sits below the one and clear of the
/// other; a widget has neither.
enum PageThemeLayout {
    case page(topInset: CGFloat)
    case widget

    var topInset: CGFloat {
        if case .page(let inset) = self { return inset }
        return 0
    }
}

// MARK: - The surface — backdrop and drawing; the app adds paper grain on top (PageThemeBackground)

struct PageThemeBackdrop: View {
    let theme: PageTheme

    var body: some View {
        switch theme.backdrop {
        case .flat(let color):
            Rectangle().fill(color)
        case .linear(let stops):
            Rectangle().fill(LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom))
        case .elliptical(let stops, let center, let radius):
            Rectangle().fill(EllipticalGradient(stops: stops, center: center, startRadiusFraction: 0,
                                                endRadiusFraction: radius))
        }
    }
}

struct PageThemePattern: View {
    let theme: PageTheme
    var layout: PageThemeLayout = .widget

    var body: some View {
        Canvas { context, size in
            ThemeArt(stage: Stage(size: size, layout: layout)).draw(theme, in: context)
        }
        .allowsHitTesting(false)
    }
}

/// Backdrop and drawing together, with an optional flat colour in place of the backdrop (the
/// widget's custom background). No grain: widgets can't run the app's shader.
struct PageThemeSurface: View {
    let theme: PageTheme
    var backdropOverride: Color? = nil

    var body: some View {
        ZStack {
            if let backdropOverride {
                Rectangle().fill(backdropOverride)
            } else {
                PageThemeBackdrop(theme: theme)
            }
            PageThemePattern(theme: theme)
        }
    }
}

// MARK: - Drawing (all Canvas — cheap, resolution-independent, no assets)

/// The themes were designed on a 300 × 620 page. A stage maps that design onto the real surface:
/// scenery keeps its proportions — scaled to the surface, up to a point — and stays pinned to the
/// edge or corner it was drawn against; textures, frames and repeats keep one size everywhere.
private struct Stage {
    let size: CGSize
    let layout: PageThemeLayout
    /// Design units to points, for scenery.
    let scale: CGFloat
    /// Design units to points, for textures, frames and repeats: the design's size on a phone page.
    let texture: CGFloat = 1.3

    init(size: CGSize, layout: PageThemeLayout) {
        self.size = size
        self.layout = layout
        scale = min(size.width / 300, size.height / 300, 1.35)
    }

    var width: CGFloat { size.width }
    var height: CGFloat { size.height }

    /// `context` in design units, with the design point `anchor` landing on `point`.
    func pinned(_ context: GraphicsContext, _ anchor: CGPoint, at point: CGPoint) -> GraphicsContext {
        var pinned = context
        pinned.translateBy(x: point.x, y: point.y)
        pinned.scaleBy(x: scale, y: scale)
        pinned.translateBy(x: -anchor.x, y: -anchor.y)
        return pinned
    }

    /// A design point spread over the whole surface — for washes and glows that belong to no edge.
    func spread(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x / 300 * width, y: y / 620 * height)
    }

    /// Where a sun or moon drawn at `center` (radius 34) goes. On a page it sits in the header's gap
    /// between the date and the controls; on a widget, in the corner it was drawn in.
    func orb(_ center: CGPoint) -> (center: CGPoint, radius: CGFloat) {
        switch layout {
        case .page(let topInset):
            return (CGPoint(x: width * 0.6, y: topInset + 34), 30)
        case .widget:
            return (CGPoint(x: width - (300 - center.x) * scale, y: center.y * scale), 34 * scale)
        }
    }
}

/// Every theme's drawing, in the approved designs' own coordinates.
private struct ThemeArt {
    let stage: Stage

    private static let heart = "M6 10.8C2.2 8 0 5.9 0 3.6 0 1.6 1.5 0 3.4 0c1.1 0 2 .5 2.6 1.4C6.6.5 7.5 0 8.6 0 10.5 0 12 1.6 12 3.6c0 2.3-2.2 4.4-6 7.2Z"
    private static let sparkle = "M0-1C.12-.24.24-.12 1 0 .24.12.12.24 0 1-.12.24-.24.12-1 0-.24-.12-.12-.24 0-1Z"

    func draw(_ theme: PageTheme, in c: GraphicsContext) {
        switch theme {
        case .paper:       break   // a plain sheet: its texture is the page's grain
        case .dots:        dots(c)
        case .grid:        graph(c)
        case .linen:       linen(c)
        case .kraft:       kraft(c)
        case .watercolor:  watercolor(c)
        case .library:     library(c)
        case .sage:        sage(c)
        case .sunrise:     sunrise(c)
        case .sunshine:    sunshine(c)
        case .clouds:      clouds(c)
        case .tide:        tide(c)
        case .riso:        riso(c)
        case .laurel:      scatter(c, ["leaf.fill", "laurel.leading"], tint: "6E9A5E", opacity: 0.3, spacing: 82)
        case .midnight:    scatter(c, ["moon.stars.fill", "star.fill", "sparkle"], tint: "6A6FA8", opacity: 0.3, spacing: 88)
        case .ballet:      scatter(c, ["heart.fill", "sparkle", "circle.fill"], tint: "E9A6B3", opacity: 0.3, spacing: 78)
        case .cherry:      scatter(c, ["heart.fill", "heart"], tint: "C4453F", opacity: 0.3, spacing: 70)
        case .stargazer:   scatter(c, ["star.fill", "sparkle", "star"], tint: "4C5578", opacity: 0.36, spacing: 62)
        case .candy:       scatter(c, ["star.fill", "sparkle", "circle.fill"], tint: "C77BB0", opacity: 0.3, spacing: 74)
        case .forest:
            scatter(c, ["leaf.fill", "laurel.trailing", "leaf"], tint: "7DB48F", opacity: 0.2, spacing: 112, sizes: 30...52)
        case .meadow:      meadow(c)
        case .garden:      garden(c)
        case .hearts:      hearts(c)
        case .bows:        bows(c)
        case .wildflowers: wildflowers(c)
        case .inkGold:     gilded(c)
        case .bubblegum:   bubblegum(c)
        case .gingham:     gingham(c)
        case .nightSky:    moonlit(c)
        case .aurora:      aurora(c)
        case .ember:       ember(c)
        case .noir:        noir(c)
        case .velvet:      velvet(c)
        case .blueprint:   blueprint(c)
        case .pine:        pine(c)
        }
    }

    // MARK: Paper

    /// Dotted: bullet-journal dots, quiet enough to write over.
    private func dots(_ c: GraphicsContext) {
        let step = 20 * stage.texture, r = 1.25 * stage.texture
        var dots = Path()
        for y in stride(from: step / 2, to: stage.height, by: step) {
            for x in stride(from: step / 2, to: stage.width, by: step) {
                dots.addPath(circle(x, y, r))
            }
        }
        c.fill(dots, with: .color(Color(hex: "33261A").opacity(0.24)))
    }

    /// Graph: engineering paper — fine squares, a firmer line every fifth.
    private func graph(_ c: GraphicsContext) {
        let green = Color(hex: "6E9C74")
        c.stroke(gridLines(every: 16 * stage.texture), with: .color(green.opacity(0.3)), lineWidth: 0.6 * stage.texture)
        c.stroke(gridLines(every: 80 * stage.texture), with: .color(green.opacity(0.45)), lineWidth: stage.texture)
    }

    /// Linen: a fine weave, with the slubs of real cloth running through it.
    private func linen(_ c: GraphicsContext) {
        let k = stage.texture, thread = Color(hex: "8A7A67")
        var weft = Path(), warp = Path()
        for y in stride(from: 0.5 * k, to: stage.height, by: 4 * k) {
            weft.move(to: CGPoint(x: 0, y: y))
            weft.addLine(to: CGPoint(x: stage.width, y: y))
        }
        for x in stride(from: 0.5 * k, to: stage.width, by: 4 * k) {
            warp.move(to: CGPoint(x: x, y: 0))
            warp.addLine(to: CGPoint(x: x, y: stage.height))
        }
        c.stroke(weft, with: .color(thread.opacity(0.16)), lineWidth: 0.6 * k)
        c.stroke(warp, with: .color(thread.opacity(0.11)), lineWidth: 0.6 * k)
        var rng = SeededRandom(seed: 21)
        let slub = Color(hex: "73614C")
        for _ in 0..<Int(stage.width * stage.height / 900) {
            let start = CGPoint(x: rng.unit() * stage.width, y: rng.unit() * stage.height)
            let length = (12 + rng.unit() * 70) * k
            var streak = Path()
            streak.move(to: start)
            streak.addLine(to: CGPoint(x: start.x + length, y: start.y))
            c.stroke(streak, with: .color(slub.opacity(0.04 + rng.unit() * 0.07)),
                     style: StrokeStyle(lineWidth: (0.6 + rng.unit()) * k, lineCap: .round))
        }
    }

    /// Kraft: brown paper lit softly from above, its fibres showing.
    private func kraft(_ c: GraphicsContext) {
        let light = Color(hex: "FFF1DA")
        glow(c, center: CGPoint(x: stage.width * 0.5, y: stage.height * 0.4),
             radii: CGSize(width: stage.width * 0.7, height: stage.height * 0.7),
             stops: [.init(color: light.opacity(0.28), location: 0), .init(color: light.opacity(0), location: 1)])
        let fibres: [(String, String, Double)] = [
            ("M6 10q6-3 13 0", "6E4F2C", 0.28), ("M32 6q5 4 12 3", "6E4F2C", 0.2), ("M62 14q4-5 11-6", "6E4F2C", 0.24),
            ("M14 34q2 6 9 9", "6E4F2C", 0.18), ("M44 30q7 1 12-3", "FFF3E0", 0.3), ("M70 38q-3 6-1 12", "6E4F2C", 0.22),
            ("M4 58q8 2 13-2", "FFF3E0", 0.26), ("M30 54q6 5 13 4", "6E4F2C", 0.26), ("M54 62q3-6 10-8", "6E4F2C", 0.18),
            ("M76 70q5 3 10 1", "FFF3E0", 0.24), ("M12 80q5-4 12-3", "6E4F2C", 0.22), ("M40 78q4 4 11 5", "6E4F2C", 0.2),
        ]
        let strands = fibres.map { (Path(svg: $0.0), Color(hex: $0.1).opacity($0.2)) }
        let k = stage.texture
        for y in stride(from: 0, to: stage.height, by: 90 * k) {
            for x in stride(from: 0, to: stage.width, by: 90 * k) {
                var tile = c
                tile.translateBy(x: x, y: y)
                tile.scaleBy(x: k, y: k)
                for (path, color) in strands {
                    tile.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
                }
            }
        }
    }

    /// Watercolor: a pastel wash bleeding in at the corners of cold-press paper.
    private func watercolor(_ c: GraphicsContext) {
        c.drawLayer { wash in
            wash.addFilter(.blur(radius: 34 * stage.scale))
            stage.pinned(wash, .zero, at: .zero)
                .fill(ellipse(30, 40, 150, 120), with: .color(Color(hex: "F4ADA2").opacity(0.5)))
            stage.pinned(wash, CGPoint(x: 150, y: 0), at: CGPoint(x: stage.width / 2, y: 0))
                .fill(ellipse(170, -10, 130, 90), with: .color(Color(hex: "A9C6EC").opacity(0.42)))
            stage.pinned(wash, CGPoint(x: 300, y: 620), at: CGPoint(x: stage.width, y: stage.height))
                .fill(ellipse(290, 640, 150, 120), with: .color(Color(hex: "F2D07D").opacity(0.32)))
        }
    }

    /// Library: an old book's page — browned toward its edges, foxed, inside a printer's double rule.
    private func library(_ c: GraphicsContext) {
        let brown = Color(hex: "7A4E28")
        glow(c, center: CGPoint(x: stage.width / 2, y: stage.height / 2),
             radii: CGSize(width: stage.width * 0.72, height: stage.height * 0.72),
             stops: [.init(color: brown.opacity(0), location: 0.55), .init(color: brown.opacity(0.34), location: 1)])
        c.drawLayer { spots in
            spots.addFilter(.blur(radius: 5 * stage.scale))
            for (x, y, r, opacity) in [(250.0, 120.0, 9.0, 0.16), (40, 470, 12, 0.14), (210, 540, 6, 0.16),
                                       (70, 210, 5, 0.12), (268, 380, 7, 0.12)] {
                let spot = stage.spread(x, y)
                spots.fill(circle(spot.x, spot.y, r * stage.scale), with: .color(Color(hex: "8A5A2B").opacity(opacity)))
            }
        }
        c.stroke(Path(frame(inset: 12, outermost: 12)), with: .color(brown.opacity(0.4)), lineWidth: stage.texture)
        c.stroke(Path(frame(inset: 16.5, outermost: 12)), with: .color(brown.opacity(0.3)), lineWidth: 0.6 * stage.texture)
    }

    // MARK: Airy

    /// Sage: sage and cream, blended like morning mist.
    private func sage(_ c: GraphicsContext) {
        c.drawLayer { mist in
            mist.addFilter(.blur(radius: 55 * stage.scale))
            for (x, y, r, color) in [(40.0, 70.0, 170.0, "C9D9BF"), (290, 320, 150, "F3F0E1"), (110, 600, 190, "D2E0CB")] {
                let center = stage.spread(x, y)
                mist.fill(circle(center.x, center.y, r * stage.scale), with: .color(Color(hex: color)))
            }
        }
    }

    /// Sunrise: a dawn sky, the sun just clearing the corner.
    private func sunrise(_ c: GraphicsContext) {
        let sun = stage.orb(CGPoint(x: 240, y: 64))
        let light = Color(hex: "FFF6E6")
        c.fill(Path(CGRect(origin: .zero, size: stage.size)),
               with: .radialGradient(Gradient(stops: [.init(color: light.opacity(0.9), location: 0),
                                                      .init(color: light.opacity(0.55), location: 0.35),
                                                      .init(color: light.opacity(0), location: 1)]),
                                     center: sun.center, startRadius: 0, endRadius: sun.radius * 150 / 34))
        c.fill(circle(sun.center.x, sun.center.y, sun.radius), with: .color(Color(hex: "FFF8EC").opacity(0.85)))
    }

    /// Sunshine: soft rays fanning down from a sun just above the page.
    private func sunshine(_ c: GraphicsContext) {
        let sky = stage.pinned(c, CGPoint(x: 150, y: 0), at: CGPoint(x: stage.width / 2, y: stage.layout.topInset))
        let rays = Path(svg: """
            M150-60L1036.3 96.2L1008.3 210.6Z M150-60L965.7 320.3L909.1 423.6Z M150-60L839.4 518.5L758 603.6Z \
            M150-60L666.2 677.3L565.5 738.3Z M150-60L457.8 785.7L344.8 818.7Z M150-60L228.5 836.6L110.8 839.1Z \
            M150-60L-6.2 826.3L-120.6 798.3Z M150-60L-230.3 755.7L-333.6 699.1Z M150-60L-428.5 629.4L-513.6 548Z \
            M150-60L-587.3 456.2L-648.3 355.5Z M150-60L-695.7 247.8L-728.7 134.8Z
            """)
        let everywhere = Path(CGRect(x: -1000, y: -400, width: 2300, height: 1700))
        sky.drawLayer { layer in
            layer.clipToLayer { fade in   // the rays fade out three quarters of the way down
                fade.fill(everywhere, with: .linearGradient(Gradient(colors: [.white, .white.opacity(0)]),
                                                            startPoint: .zero, endPoint: CGPoint(x: 0, y: 465)))
            }
            layer.fill(rays, with: .color(Color(hex: "F2C35B").opacity(0.2)))
        }
        let warmth = Color(hex: "FFE08A")
        sky.fill(everywhere, with: .radialGradient(Gradient(colors: [warmth.opacity(0.9), warmth.opacity(0)]),
                                                   center: CGPoint(x: 150, y: -40), startRadius: 0, endRadius: 190))
        sky.fill(circle(150, -40, 62), with: .color(Color(hex: "FFD66B").opacity(0.75)))
    }

    /// Clouds: a cloud bank resting along the foot of the page, two strays drifting above it.
    private func clouds(_ c: GraphicsContext) {
        var puff = Path()
        for (x, y, r) in [(9.0, 13.0, 6.0), (17.5, 9, 8), (26.5, 13, 6)] { puff.addPath(circle(x, y, r)) }
        puff.addRect(CGRect(x: 9, y: 12, width: 17.5, height: 7))
        stage.pinned(c, CGPoint(x: 300, y: 0), at: CGPoint(x: stage.width, y: 0))
            .fill(puff.applying(CGAffineTransform(translationX: 196, y: 236).scaledBy(x: 1.7, y: 1.7)), with: .color(.white.opacity(0.7)))
        stage.pinned(c, .zero, at: .zero)
            .fill(puff.applying(CGAffineTransform(translationX: 18, y: 392).scaledBy(x: 1.2, y: 1.2)), with: .color(.white.opacity(0.7)))

        var back = Path(), front = Path()
        for (x, y, r) in [(20.0, 585.0, 55.0), (85, 565, 60), (155, 580, 58), (225, 560, 64), (295, 580, 56)] {
            back.addPath(circle(x, y, r))
        }
        for (x, y, r) in [(0.0, 615.0, 48.0), (60, 605, 52), (120, 618, 46), (180, 600, 54), (245, 612, 50), (305, 605, 48)] {
            front.addPath(circle(x, y, r))
        }
        // The bank repeats every 300 units across a wider surface; each layer goes down for the
        // whole width before the next, so no repeat's shadow lands on its neighbour.
        let banks = stride(from: 0, to: stage.width, by: 300 * stage.scale).map {
            stage.pinned(c, CGPoint(x: 0, y: 620), at: CGPoint(x: $0, y: stage.height))
        }
        for bank in banks { bank.fill(back, with: .color(.white.opacity(0.72))) }
        for bank in banks {
            bank.drawLayer { shadow in
                shadow.addFilter(.blur(radius: 6 * stage.scale))
                shadow.translateBy(x: 0, y: 6)
                shadow.fill(front, with: .color(Color(hex: "B9D6EF").opacity(0.55)))
            }
        }
        for bank in banks { bank.fill(front, with: .color(.white)) }
    }

    /// Tide: still water with soft rolling lines.
    private func tide(_ c: GraphicsContext) {
        let k = stage.texture
        let wave = Path(svg: "M0 13C23 8.5 23 8.5 46 13S69 17.5 92 13")
        var water = Path()
        for y in stride(from: 0, to: stage.height, by: 26 * k) {
            for x in stride(from: 0, to: stage.width, by: 92 * k) {
                water.addPath(wave, transform: CGAffineTransform(translationX: x, y: y).scaledBy(x: k, y: k))
            }
        }
        c.stroke(water, with: .color(Color(hex: "6FA6B8").opacity(0.34)), lineWidth: 1.2 * k)
    }

    /// Riso: risograph halftone — pink dots swelling toward one corner, a blue pass fading from the other.
    private func riso(_ c: GraphicsContext) {
        let k = stage.texture, pitch = 9 * k
        let reach = 520 * stage.scale, fadeReach = 240 * stage.scale
        var pink = Path()
        let blue = Color(hex: "3D6BE8")
        for y in stride(from: pitch / 2, to: stage.height, by: pitch) {
            for x in stride(from: pitch / 2, to: stage.width, by: pitch) {
                switch hypot(x, stage.height - y) / reach {
                case ..<0.32: pink.addPath(circle(x, y, 3 * k))
                case ..<0.58: pink.addPath(circle(x, y, 2 * k))
                case ..<0.83: pink.addPath(circle(x, y, 1.1 * k))
                default: break
                }
                let fade = hypot(stage.width - x, y) / fadeReach
                guard fade < 1 else { continue }
                let strength = fade < 0.7 ? 1 - 0.6 * fade / 0.7 : 0.4 * (1 - fade) / 0.3
                c.fill(circle(x + 2 * k, y + 2 * k, 1.1 * k), with: .color(blue.opacity(0.22 * strength)))
            }
        }
        c.fill(pink, with: .color(Color(hex: "FF6F91").opacity(0.42)))
    }

    // MARK: Scattered

    /// The first set's scattered symbols, placed exactly as they always were.
    private func scatter(_ c: GraphicsContext, _ symbols: [String], tint: String, opacity: Double,
                         spacing: CGFloat, sizes: ClosedRange<CGFloat> = 13...25) {
        var rng = SeededRandom(seed: 9)
        let resolved = symbols.map { name in
            var symbol = c.resolve(Image(systemName: name))
            symbol.shading = .color(Color(hex: tint))
            return symbol
        }
        for row in 0..<(Int(stage.height / spacing) + 2) {
            for column in 0..<(Int(stage.width / spacing) + 2) {
                let stagger: CGFloat = row.isMultiple(of: 2) ? 0 : spacing / 2
                let x = CGFloat(column) * spacing + stagger + rng.jitter(spacing * 0.36)
                let y = CGFloat(row) * spacing + rng.jitter(spacing * 0.36)
                let side = sizes.lowerBound + rng.unit() * (sizes.upperBound - sizes.lowerBound)
                let rotation = Angle.degrees((rng.unit() - 0.5) * 40)
                let symbol = resolved[rng.pick(resolved.count)]
                c.drawLayer { layer in
                    layer.opacity = opacity
                    layer.translateBy(x: x, y: y)
                    layer.rotate(by: rotation)
                    layer.draw(symbol, in: CGRect(x: -side / 2, y: -side / 2, width: side, height: side))
                }
            }
        }
    }

    // MARK: Prints

    /// Meadow: leaves and laurel sprigs scattered by hand, the handful repeated down the page.
    private func meadow(_ c: GraphicsContext) {
        let green = Color(hex: "6E9A5E")
        let leaf = Path(svg: "M0-8C5-4 5 4 0 8-5 4-5-4 0-8Z")
        let vein = Path(svg: "M0-6.5V6.5")
        let stem = Path(svg: "M0 10C1 4-1-2 0-10")
        var sprig = Path()
        for (x, y, degrees) in [(-2.6, 6.0, -40.0), (2.6, 2, 40), (-2.6, -2, -40), (2.6, -6, 40)] {
            sprig.addPath(ellipse(0, 0, 2.8, 1.3),
                          transform: CGAffineTransform(translationX: x, y: y).rotated(by: degrees * .pi / 180))
        }
        sprig.addPath(ellipse(0, -10.5, 1.3, 2.4))
        let placements: [(leaf: Bool, x: CGFloat, y: CGFloat, degrees: Double, scale: CGFloat)] = [
            (true, 28, 40, 20, 1), (false, 110, 70, -30, 0.8), (true, 200, 30, 60, 1.1), (false, 268, 96, -10, 0.9),
            (false, 60, 150, -50, 0.9), (true, 150, 170, 30, 1), (true, 240, 190, 80, 0.8), (true, 20, 250, 10, 1.1),
            (false, 95, 280, -70, 0.9), (false, 185, 300, 45, 1), (true, 275, 280, -20, 1), (true, 50, 380, 70, 0.8),
            (false, 140, 400, -15, 1.1), (true, 230, 390, 25, 0.9), (false, 10, 480, -40, 1), (true, 90, 500, 15, 1),
            (true, 180, 520, -60, 0.8), (false, 265, 490, 40, 1.1), (true, 45, 590, -25, 0.9), (false, 135, 600, 55, 1),
            (true, 220, 605, -5, 1), (false, 290, 580, 70, 0.8),
        ]
        let k = stage.texture
        c.drawLayer { layer in
            layer.opacity = 0.32
            for tileY in stride(from: 0, to: stage.height, by: 620 * k) {
                for tileX in stride(from: 0, to: stage.width, by: 300 * k) {
                    for placement in placements {
                        var piece = layer
                        piece.translateBy(x: tileX + placement.x * k, y: tileY + placement.y * k)
                        piece.rotate(by: .degrees(placement.degrees))
                        piece.scaleBy(x: placement.scale * k, y: placement.scale * k)
                        if placement.leaf {
                            piece.fill(leaf, with: .color(green))
                            piece.stroke(vein, with: .color(Color(hex: "EEF3E6")), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                        } else {
                            piece.stroke(stem, with: .color(green), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                            piece.fill(sprig, with: .color(green))
                        }
                    }
                }
            }
        }
    }

    /// Garden: a fringe of grass along the foot of the page, small flowers in it.
    private func garden(_ c: GraphicsContext) {
        let size = stage.size
        var rng = SeededRandom(seed: 5)
        let height = min(80, size.height * 0.24)
        let greens = [Color(hex: "6E9A5E"), Color(hex: "86B26F"), Color(hex: "5C8A52")]
        var x: CGFloat = -4
        while x < size.width + 4 {
            let blade = height * (0.45 + rng.unit() * 0.55)
            let lean = rng.jitter(10)
            var path = Path()
            path.move(to: CGPoint(x: x - 1.4, y: size.height))
            path.addQuadCurve(to: CGPoint(x: x + lean, y: size.height - blade),
                              control: CGPoint(x: x + lean * 0.2, y: size.height - blade * 0.6))
            path.addQuadCurve(to: CGPoint(x: x + 1.4, y: size.height),
                              control: CGPoint(x: x + lean * 0.3, y: size.height - blade * 0.55))
            path.closeSubpath()
            c.fill(path, with: .color(greens[rng.pick(greens.count)].opacity(0.26 + rng.unit() * 0.28)))
            x += 2.5 + rng.unit() * 3
        }
        let petals = [Color(hex: "F2C94C"), Color(hex: "E9A6B3"), Color.white]
        for _ in 0..<max(2, Int(size.width / 34)) {
            let center = CGPoint(x: rng.unit() * size.width,
                                 y: size.height - height * (0.25 + rng.unit() * 0.7))
            let r = 2.2 + rng.unit() * 2.4
            let color = petals[rng.pick(petals.count)]
            for petal in 0..<5 {
                let angle = CGFloat(petal) / 5 * .pi * 2
                c.fill(circle(center.x + cos(angle) * r, center.y + sin(angle) * r, r * 0.75), with: .color(color.opacity(0.7)))
            }
            c.fill(circle(center.x, center.y, r * 0.5), with: .color(Color(hex: "E3A94A").opacity(0.85)))
        }
    }

    /// Hearts: tiny hearts in a neat half-drop repeat.
    private func hearts(_ c: GraphicsContext) {
        let k = stage.texture, tile = 34 * k
        let heart = Path(svg: Self.heart)
        var hearts = Path(), dots = Path()
        for y in stride(from: 0, to: stage.height, by: tile) {
            for x in stride(from: 0, to: stage.width, by: tile) {
                for (dx, dy) in [(4.0, 4.0), (21, 21)] {
                    hearts.addPath(heart, transform: CGAffineTransform(translationX: x + dx * k, y: y + dy * k)
                        .scaledBy(x: 0.75 * k, y: 0.75 * k))
                }
                dots.addPath(circle(x + 25.5 * k, y + 8 * k, 1.1 * k))
                dots.addPath(circle(x + 8.5 * k, y + 25 * k, 1.1 * k))
            }
        }
        let pink = Color(hex: "E7889A")
        c.fill(hearts, with: .color(pink.opacity(0.5)))
        c.fill(dots, with: .color(pink.opacity(0.28)))
    }

    /// Bows: a ribbon garland swagged along the top, a bow at each pin and a heart hanging between.
    private func bows(_ c: GraphicsContext) {
        // On a page the pins sit just under the status bar, and the header leaves room beneath
        // (`PageTheme.headerClearance`).
        let pinY: CGFloat
        if case .page(let topInset) = stage.layout { pinY = topInset + 2 } else { pinY = 12 * stage.scale }
        let garland = stage.pinned(c, CGPoint(x: 150, y: 12), at: CGPoint(x: stage.width / 2, y: pinY))
        let bow = Path(svg: """
            M11 6.5C7.4 2.2 2.6.9 1.3 3.5.3 5.6 2.6 9 11 6.5Z M11 6.5C14.6 2.2 19.4.9 20.7 3.5c1 2.1-1.3 5.5-9.7 3Z \
            M10.2 7.4 7.6 14l2.1-.9 1 1.5.5-7.2Z M11.8 7.4 14.4 14l-2.1-.9-1 1.5-.5-7.2Z
            """)
        let heart = Path(svg: Self.heart)
        var ribbon = Path(), shine = Path(), strings = Path(), hearts = Path(), bows = Path(), pins = Path()
        let spans = Int(stage.width / 2 / (120 * stage.scale)) + 2
        for span in -spans...spans {
            let pin = 150 + CGFloat(span) * 120
            ribbon.move(to: CGPoint(x: pin, y: 12))
            ribbon.addQuadCurve(to: CGPoint(x: pin + 120, y: 12), control: CGPoint(x: pin + 60, y: 64))
            shine.move(to: CGPoint(x: pin, y: 11))
            shine.addQuadCurve(to: CGPoint(x: pin + 120, y: 11), control: CGPoint(x: pin + 60, y: 62))
            strings.move(to: CGPoint(x: pin + 60, y: 38))
            strings.addLine(to: CGPoint(x: pin + 60, y: 50))
            hearts.addPath(heart, transform: CGAffineTransform(translationX: pin + 56, y: 49).scaledBy(x: 0.66, y: 0.66))
            bows.addPath(bow, transform: CGAffineTransform(translationX: pin - 16.5, y: 1.8).scaledBy(x: 1.5, y: 1.5))
            pins.addPath(circle(pin, 12, 2.8))
        }
        let rose = Color(hex: "E58FA5")
        garland.stroke(ribbon, with: .color(rose), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
        garland.stroke(shine, with: .color(Color(hex: "F9D2DC").opacity(0.9)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        garland.stroke(strings, with: .color(rose), lineWidth: 0.8)
        garland.fill(hearts, with: .color(rose))
        garland.fill(bows, with: .color(Color(hex: "DE7E95")))
        garland.fill(pins, with: .color(Color(hex: "C9667F")))
    }

    /// Wildflowers: two little bouquets gathered in opposite corners.
    private func wildflowers(_ c: GraphicsContext) {
        let top: CGFloat
        if case .page(let topInset) = stage.layout { top = topInset - 14 } else { top = 0 }
        bouquet(stage.pinned(c, CGPoint(x: 300, y: 0), at: CGPoint(x: stage.width, y: top)),
                flowers: ["E4A0A6", "F0C96A", "B9A8D8", "F2B08A"])
        // The lower bouquet is the upper one turned half round, its first two flowers swapped.
        var lower = stage.pinned(c, CGPoint(x: 0, y: 620), at: CGPoint(x: 0, y: stage.height))
        lower.translateBy(x: 150, y: 310)
        lower.rotate(by: .degrees(180))
        lower.translateBy(x: -150, y: -310)
        bouquet(lower, flowers: ["F0C96A", "E4A0A6", "B9A8D8", "F2B08A"])
    }

    /// One bouquet, as drawn in the design's top-right corner.
    private func bouquet(_ c: GraphicsContext, flowers: [String]) {
        c.drawLayer { layer in
            layer.opacity = 0.85
            var leaves = Path()
            for (x, y, rx, ry, degrees) in [(226.0, 22.0, 8.0, 3.0, -25.0), (292, 54, 8, 3, 70), (246, 78, 7, 2.6, 30),
                                            (214, 56, 6, 2.4, -60), (270, 110, 7, 2.6, -20)] {
                leaves.addPath(ellipse(0, 0, rx, ry),
                               transform: CGAffineTransform(translationX: x, y: y).rotated(by: degrees * .pi / 180))
            }
            layer.fill(leaves, with: .color(Color(hex: "9DB58E")))
            var petals = Path()
            for petal in 0..<5 {
                let angle = CGFloat(petal) / 5 * .pi * 2
                petals.addPath(circle(2.7 * cos(angle), 2.7 * sin(angle), 2.6))
            }
            for (index, (x, y, scale)) in [(262.0, 28.0, 2.6), (230, 50, 1.8), (282, 86, 2), (244, 98, 1.3)].enumerated() {
                let place = CGAffineTransform(translationX: x, y: y).scaledBy(x: scale, y: scale)
                // Yellow and peach flowers have amber hearts; rose and lilac, butter-yellow ones.
                let centre = ["F0C96A", "F2B08A"].contains(flowers[index]) ? "C98E3A" : "F2D27A"
                layer.fill(petals.applying(place), with: .color(Color(hex: flowers[index])))
                layer.fill(circle(0, 0, 1.5).applying(place), with: .color(Color(hex: centre)))
            }
            var buds = Path()
            for (x, y, r) in [(206.0, 34.0, 2.0), (298, 120, 2), (262, 128, 1.6), (218, 82, 1.6)] { buds.addPath(circle(x, y, r)) }
            layer.fill(buds, with: .color(Color(hex: "E4A0A6")))
        }
    }

    /// Gilded: a comet tail of gold sparkles sweeping up the page.
    private func gilded(_ c: GraphicsContext) {
        let gold = Color(hex: "B8903F")
        let sweep = stage.pinned(c, CGPoint(x: 300, y: 620), at: CGPoint(x: stage.width, y: stage.height))
        sweep.stroke(Path(svg: "M0 640Q200 600 320 280"), with: .color(gold.opacity(0.28)), lineWidth: 1)
        sweep.stroke(Path(svg: "M-10 628Q196 584 312 262"), with: .color(gold.opacity(0.16)), lineWidth: 0.6)
        let sparkle = Path(svg: Self.sparkle)
        let tail: [(CGFloat, CGFloat, CGFloat, Double)] = [
            (60, 612, 3, 0.35), (78, 596, 2, 0.3), (96, 604, 4, 0.4), (118, 584, 2.5, 0.35), (132, 572, 5, 0.45),
            (150, 560, 3, 0.4), (166, 540, 6, 0.5), (182, 528, 3, 0.45), (198, 506, 7, 0.55), (214, 492, 3.5, 0.5),
            (228, 466, 8, 0.6), (242, 448, 4, 0.55), (256, 422, 9, 0.68), (268, 402, 4.5, 0.6), (278, 372, 13, 0.82),
            (294, 348, 5, 0.6), (260, 356, 3, 0.5), (288, 326, 3.5, 0.5), (246, 392, 2.5, 0.4), (212, 470, 2, 0.35),
            (180, 560, 2, 0.3),
        ]
        for (x, y, size, opacity) in tail {
            sweep.fill(sparkle.applying(CGAffineTransform(translationX: x, y: y).scaledBy(x: size, y: size)),
                       with: .color(gold.opacity(opacity)))
        }
        var dust = Path()
        for (x, y) in [(140.0, 590.0), (206, 530), (250, 470), (300, 300), (270, 340)] { dust.addPath(circle(x, y, 1)) }
        sweep.fill(dust, with: .color(gold.opacity(0.4)))
    }

    /// Bubblegum: big Matisse-style cut-outs in candy colours.
    private func bubblegum(_ c: GraphicsContext) {
        let topRight = stage.pinned(c, CGPoint(x: 300, y: 0), at: CGPoint(x: stage.width, y: 0))
        let bottomLeft = stage.pinned(c, CGPoint(x: 0, y: 620), at: CGPoint(x: 0, y: stage.height))
        let bottomRight = stage.pinned(c, CGPoint(x: 300, y: 620), at: CGPoint(x: stage.width, y: stage.height))
        let left = stage.pinned(c, CGPoint(x: 0, y: 310), at: CGPoint(x: 0, y: stage.height / 2))
        topRight.fill(Path(svg: "M210-30C280-40 340 20 320 90 305 140 250 150 230 120 210 90 170 100 160 60 150 20 170-25 210-30Z"),
                      with: .color(Color(hex: "F6B3CF").opacity(0.72)))
        bottomLeft.fill(Path(svg: "M-40 470C10 440 70 470 90 520 110 570 80 640 20 650-30 660-70 600-60 550-55 510-70 490-40 470Z"),
                        with: .color(Color(hex: "CDB8F2").opacity(0.66)))
        bottomRight.fill(Path(svg: "M230 540C260 520 300 540 296 575 292 605 255 615 236 598 218 582 205 556 230 540Z"),
                         with: .color(Color(hex: "FFC9AE").opacity(0.75)))
        left.fill(Path(svg: """
            M20 300C40 270 60 280 55 300 75 290 85 310 65 320 85 335 70 355 52 342 50 365 28 365 30 342 \
            10 350 5 330 22 322 5 310 8 292 20 300Z
            """), with: .color(Color(hex: "EE8DB8").opacity(0.5)))
        topRight.fill(circle(262, 176, 6), with: .color(Color(hex: "CDB8F2").opacity(0.7)))
        bottomLeft.fill(circle(120, 590, 4), with: .color(Color(hex: "F6B3CF").opacity(0.8)))
    }

    /// Gingham: red picnic check, deeper where the bands cross.
    private func gingham(_ c: GraphicsContext) {
        let band = 14 * stage.texture
        var across = Path(), down = Path()
        for y in stride(from: 0, to: stage.height, by: band * 2) {
            across.addRect(CGRect(x: 0, y: y, width: stage.width, height: band))
        }
        for x in stride(from: 0, to: stage.width, by: band * 2) {
            down.addRect(CGRect(x: x, y: 0, width: band, height: stage.height))
        }
        let red = Color(hex: "E26D6D").opacity(0.13)
        c.fill(across, with: .color(red))
        c.fill(down, with: .color(red))
    }

    // MARK: Dark

    /// Moonlit: a navy night — a field of stars, a faint Milky Way, a crescent moon up in the corner.
    private func moonlit(_ c: GraphicsContext) {
        let starlight = Color(hex: "FFF3D4")
        c.drawLayer { haze in
            let center = stage.spread(150, 330)
            haze.addFilter(.blur(radius: 26 * stage.scale))
            haze.translateBy(x: center.x, y: center.y)
            haze.rotate(by: .degrees(-28))
            haze.fill(ellipse(0, 0, 70 * stage.scale, 360 * stage.scale), with: .color(Color(hex: "C9D4FF").opacity(0.08)))
        }
        stars(c, every: 113, color: starlight, [
            (12, 18, 0.8, 0.9), (47, 6, 0.6, 0.6), (80, 30, 1.1, 0.8), (102, 64, 0.7, 0.5), (30, 72, 0.9, 0.7),
            (64, 96, 0.6, 0.6), (90, 104, 1, 0.9), (8, 100, 0.6, 0.5), (55, 48, 0.5, 0.5),
        ])
        stars(c, every: 167, color: starlight, [
            (20, 40, 1.3, 0.9), (140, 20, 0.8, 0.7), (90, 80, 0.6, 0.5), (150, 130, 1.1, 0.8), (40, 150, 0.7, 0.6),
            (110, 150, 0.5, 0.5), (70, 10, 0.6, 0.6),
        ])
        let sparkle = Path(svg: Self.sparkle)
        for (x, y, size, opacity) in [(236.0, 150.0, 5.0, 0.85), (60, 330, 3.5, 0.7), (250, 470, 4, 0.75), (120, 560, 3, 0.6)] {
            let point = stage.spread(x, y)
            let side = size * stage.scale
            c.fill(sparkle.applying(CGAffineTransform(translationX: point.x, y: point.y).scaledBy(x: side, y: side)),
                   with: .color(starlight.opacity(opacity)))
        }
        // The book cover's moon: a disc with a smaller one taken out of its upper right.
        let moon = stage.orb(CGPoint(x: 232, y: 62))
        let r = moon.radius
        let crescent = circle(moon.center.x, moon.center.y, r)
            .subtracting(circle(moon.center.x + r / 2, moon.center.y - r * 5 / 14, r * 11 / 14))
        let moonlight = Color(hex: "F5E7B5")
        c.drawLayer { halo in
            halo.addFilter(.blur(radius: r * 0.3))
            halo.fill(crescent, with: .color(moonlight.opacity(0.35)))
        }
        c.fill(crescent, with: .color(moonlight))
    }

    /// Aurora: curtains of teal and violet light hanging in the dark.
    private func aurora(_ c: GraphicsContext) {
        let stretch = CGAffineTransform(scaleX: stage.width / 300, y: stage.height / 620)
        let curtains: [(String, String, String, Double, CGFloat)] = [
            ("M-40 230C60 170 160 290 340 200L340 310C180 380 80 270-40 340Z", "2DD4A8", "3A8FD6", 0.5, 22),
            ("M-40 370C80 320 170 440 340 360L340 450C200 510 90 410-40 470Z", "7C5CE0", "D16BA5", 0.42, 28),
        ]
        for (data, from, to, opacity, blur) in curtains {
            let curtain = Path(svg: data).applying(stretch)
            let bounds = curtain.boundingRect
            c.drawLayer { light in
                light.opacity = opacity
                light.addFilter(.blur(radius: blur * stage.scale))
                light.fill(curtain, with: .linearGradient(Gradient(colors: [Color(hex: from), Color(hex: to)]),
                                                          startPoint: CGPoint(x: bounds.minX, y: 0),
                                                          endPoint: CGPoint(x: bounds.maxX, y: 0)))
            }
        }
        var stars = Path()
        for (x, y, r) in [(40.0, 60.0, 0.7), (220, 40, 0.9), (270, 140, 0.6), (120, 120, 0.6), (60, 540, 0.7), (250, 580, 0.8),
                          (170, 600, 0.6)] {
            let point = stage.spread(x, y)
            stars.addPath(circle(point.x, point.y, r * stage.texture))
        }
        c.fill(stars, with: .color(.white.opacity(0.55)))
    }

    /// Ember: a fire's glow rising from below, sparks drifting up.
    private func ember(_ c: GraphicsContext) {
        let s = stage.scale
        glow(c, center: CGPoint(x: stage.width / 2, y: stage.height + 60 * s), radii: CGSize(width: 430 * s, height: 380 * s),
             stops: [.init(color: Color(hex: "F0611A").opacity(0.6), location: 0),
                     .init(color: Color(hex: "B8360F").opacity(0.22), location: 0.45),
                     .init(color: Color(hex: "B8360F").opacity(0), location: 1)])
        let sparks: [(CGFloat, CGFloat, CGFloat, Double)] = [
            (40, 520, 1.4, 0.7), (70, 470, 1, 0.5), (110, 540, 1.8, 0.8), (150, 430, 1.1, 0.5), (180, 500, 1.5, 0.7),
            (220, 560, 1.2, 0.6), (250, 450, 1.6, 0.6), (270, 520, 1, 0.5), (90, 390, 0.9, 0.4), (200, 380, 1, 0.4),
            (130, 600, 1.3, 0.7), (60, 580, 1, 0.6), (240, 600, 1.4, 0.7), (160, 350, 0.8, 0.3), (285, 410, 0.9, 0.4),
            (20, 440, 0.9, 0.4),
        ]
        for (x, y, r, opacity) in sparks {
            c.fill(circle(x / 300 * stage.width, stage.height - (620 - y) * s, r * stage.texture),
                   with: .color(Color(hex: "F7A44A").opacity(opacity)))
        }
    }

    /// Noir: black with gold pinstripes, inside an art-deco frame.
    private func noir(_ c: GraphicsContext) {
        let k = stage.texture, gold = Color(hex: "C9A45C")
        var stripes = Path()
        for x in stride(from: 0, to: stage.width + stage.height, by: 18 * k * 2.squareRoot()) {
            stripes.move(to: CGPoint(x: x, y: 0))
            stripes.addLine(to: CGPoint(x: x - stage.height, y: stage.height))
        }
        c.stroke(stripes, with: .color(gold.opacity(0.18)), lineWidth: 0.8 * k)
        let outer = frame(inset: 14, outermost: 14)
        c.stroke(Path(outer), with: .color(gold.opacity(0.55)), lineWidth: k)
        c.stroke(Path(frame(inset: 19, outermost: 14)), with: .color(gold.opacity(0.3)), lineWidth: 0.6 * k)
        // Three quarter-circle fans tucked into each corner of the outer rule.
        var fans = Path()
        let corners: [(CGPoint, CGFloat)] = [(CGPoint(x: outer.minX, y: outer.minY), 0), (CGPoint(x: outer.maxX, y: outer.minY), 90),
                                             (CGPoint(x: outer.maxX, y: outer.maxY), 180), (CGPoint(x: outer.minX, y: outer.maxY), 270)]
        for (corner, start) in corners {
            for radius in [10, 16, 22] as [CGFloat] {
                for step in 0...12 {
                    let angle = (start + CGFloat(step) * 90 / 12) * .pi / 180
                    let point = CGPoint(x: corner.x + cos(angle) * radius * k, y: corner.y + sin(angle) * radius * k)
                    if step == 0 { fans.move(to: point) } else { fans.addLine(to: point) }
                }
            }
        }
        c.stroke(fans, with: .color(gold.opacity(0.5)), lineWidth: 0.8 * k)
    }

    /// Velvet: plum with the soft sheen of velvet pile.
    private func velvet(_ c: GraphicsContext) {
        // The sheen runs corner to corner across the page whatever its shape, so it's laid out on
        // the page stretched to a unit square.
        var sheen = c
        sheen.scaleBy(x: stage.width, y: stage.height)
        sheen.fill(Path(CGRect(x: 0, y: 0, width: 1, height: 1)),
                   with: .linearGradient(Gradient(stops: [.init(color: .white.opacity(0), location: 0.38),
                                                          .init(color: .white.opacity(0.09), location: 0.46),
                                                          .init(color: .white.opacity(0), location: 0.54)]),
                                         startPoint: .zero, endPoint: CGPoint(x: 1, y: 1)))
    }

    /// Blueprint: cobalt drafting paper — a grid, a compass circle and a scale bar.
    private func blueprint(_ c: GraphicsContext) {
        let k = stage.texture
        c.stroke(gridLines(every: 20 * k), with: .color(.white.opacity(0.1)), lineWidth: 0.6 * k)
        c.stroke(gridLines(every: 100 * k), with: .color(.white.opacity(0.2)), lineWidth: k)
        let compass = stage.pinned(c, CGPoint(x: 300, y: 620), at: CGPoint(x: stage.width, y: stage.height))
        compass.stroke(circle(236, 530, 48), with: .color(.white.opacity(0.28)), style: StrokeStyle(lineWidth: 0.9, dash: [4, 3]))
        compass.stroke(circle(236, 530, 22), with: .color(.white.opacity(0.22)), lineWidth: 0.7)
        compass.stroke(Path(svg: "M176 530H296M236 470V590"), with: .color(.white.opacity(0.2)), lineWidth: 0.6)
        stage.pinned(c, CGPoint(x: 0, y: 620), at: CGPoint(x: 0, y: stage.height))
            .stroke(Path(svg: "M30 592H170M30 586V598M170 586V598"), with: .color(.white.opacity(0.3)), lineWidth: 0.8)
    }

    /// Pine: green-black, with low mist drifting across.
    private func pine(_ c: GraphicsContext) {
        c.drawLayer { mist in
            mist.addFilter(.blur(radius: 18 * stage.scale))
            for (x, y, rx, ry, opacity) in [(80.0, 340.0, 220.0, 34.0, 0.1), (230, 460, 240, 40, 0.12), (120, 575, 260, 46, 0.15)] {
                let center = stage.spread(x, y)
                mist.fill(ellipse(center.x, center.y, rx / 300 * stage.width, ry * stage.scale),
                          with: .color(Color(hex: "BFE0C8").opacity(opacity)))
            }
        }
    }

    // MARK: Shapes

    private func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    private func ellipse(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2))
    }

    /// Lines across and down the surface every `step` points.
    private func gridLines(every step: CGFloat) -> Path {
        var lines = Path()
        for x in stride(from: step, to: stage.width, by: step) {
            lines.move(to: CGPoint(x: x, y: 0))
            lines.addLine(to: CGPoint(x: x, y: stage.height))
        }
        for y in stride(from: step, to: stage.height, by: step) {
            lines.move(to: CGPoint(x: 0, y: y))
            lines.addLine(to: CGPoint(x: stage.width, y: y))
        }
        return lines
    }

    /// A rule `inset` design units in from the edges. On a page its top runs just under the status
    /// bar instead, the rules inside it (`inset` past `outermost`) keeping their spacing.
    private func frame(inset: CGFloat, outermost: CGFloat) -> CGRect {
        let k = stage.texture
        let top = max(inset * k, stage.layout.topInset - 6 + (inset - outermost) * k)
        return CGRect(x: inset * k, y: top, width: stage.width - inset * k * 2, height: stage.height - inset * k - top)
    }

    /// A radial fill stretched into an ellipse, as SVG draws one across a page that isn't square.
    private func glow(_ c: GraphicsContext, center: CGPoint, radii: CGSize, stops: [Gradient.Stop]) {
        var glow = c
        glow.translateBy(x: center.x, y: center.y)
        glow.scaleBy(x: radii.width, y: radii.height)
        let page = CGRect(x: -center.x / radii.width, y: -center.y / radii.height,
                          width: stage.width / radii.width, height: stage.height / radii.height)
        glow.fill(Path(page), with: .radialGradient(Gradient(stops: stops), center: .zero, startRadius: 0, endRadius: 1))
    }

    /// A tile of pinprick stars, `every` design units square, repeated over the surface.
    private func stars(_ c: GraphicsContext, every tile: CGFloat, color: Color, _ stars: [(CGFloat, CGFloat, CGFloat, Double)]) {
        let k = stage.texture
        for y in stride(from: 0, to: stage.height, by: tile * k) {
            for x in stride(from: 0, to: stage.width, by: tile * k) {
                for (sx, sy, r, opacity) in stars {
                    c.fill(circle(x + sx * k, y + sy * k, r * k), with: .color(color.opacity(opacity)))
                }
            }
        }
    }
}

// MARK: - SVG path data

private extension Path {
    /// A path from SVG path data, so the themes' shapes stay exactly as designed. Reads the commands
    /// those designs use — M L H V C S Q Z, absolute and relative.
    init(svg data: String) {
        self.init()
        var reader = SVGPathReader(data)
        var command: Character = "M"
        var point = CGPoint.zero, start = CGPoint.zero
        var lastControl: CGPoint?
        while !reader.isAtEnd {
            let position = reader.position
            if let letter = reader.command() { command = letter }
            let origin = command.isLowercase ? point : .zero
            func next() -> CGPoint {
                let x = reader.number(), y = reader.number()
                return CGPoint(x: origin.x + x, y: origin.y + y)
            }
            var control: CGPoint?
            switch command.uppercased() {
            case "M":
                point = next()
                start = point
                move(to: point)
                command = command.isLowercase ? "l" : "L"   // further pairs are lines
            case "L":
                point = next()
                addLine(to: point)
            case "H":
                point.x = origin.x + reader.number()
                addLine(to: point)
            case "V":
                point.y = origin.y + reader.number()
                addLine(to: point)
            case "C":
                let first = next(), second = next(), end = next()
                addCurve(to: end, control1: first, control2: second)
                control = second
                point = end
            case "S":
                let first = lastControl.map { CGPoint(x: point.x * 2 - $0.x, y: point.y * 2 - $0.y) } ?? point
                let second = next(), end = next()
                addCurve(to: end, control1: first, control2: second)
                control = second
                point = end
            case "Q":
                let middle = next(), end = next()
                addQuadCurve(to: end, control: middle)
                point = end
            case "Z":
                closeSubpath()
                point = start
            default:
                return
            }
            lastControl = control
            if reader.position == position { return }   // nothing could be read: malformed data
        }
    }
}

/// Reads SVG path data a command letter or a number at a time.
private struct SVGPathReader {
    private let characters: [Character]
    private(set) var position = 0

    init(_ data: String) { characters = Array(data) }

    var isAtEnd: Bool {
        mutating get {
            skipSeparators()
            return position >= characters.count
        }
    }

    /// The command letter here, if there is one; otherwise the last command repeats.
    mutating func command() -> Character? {
        skipSeparators()
        guard position < characters.count, characters[position].isLetter else { return nil }
        defer { position += 1 }
        return characters[position]
    }

    mutating func number() -> CGFloat {
        skipSeparators()
        let begin = position
        if position < characters.count, characters[position] == "-" || characters[position] == "+" { position += 1 }
        var sawPoint = false
        while position < characters.count {
            let character = characters[position]
            if character.isNumber {
                position += 1
            } else if character == ".", !sawPoint {
                sawPoint = true
                position += 1
            } else {
                break
            }
        }
        return CGFloat(Double(String(characters[begin..<position])) ?? 0)
    }

    private mutating func skipSeparators() {
        while position < characters.count, characters[position] == " " || characters[position] == "," || characters[position] == "\n" {
            position += 1
        }
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
