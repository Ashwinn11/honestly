import SwiftUI

// MARK: - The cover designs

/// The illustrated, patterned and classic covers a month book can wear. Every one is drawn in code
/// (no image files), each with its own way of carrying the month's name. Each month starts on its
/// own design — `forMonth` never gives two months in a row the same one — and the cover editor
/// can swap it any time.
enum CoverDesign: String, CaseIterable, Identifiable, Codable {
    case bouquet, botanical, night, daisies, waves, sunrise, mountains, clouds, citrus, arches
    case littleFlorals, tambourine, quilted, gingham, checker, groovy, dots, terrazzo
    case goldFoil, library, leather, kraft, plainCloth

    var id: String { rawValue }

    enum Group: CaseIterable { case illustrated, patterns, classic }

    var group: Group {
        switch self {
        case .bouquet, .botanical, .night, .daisies, .waves, .sunrise, .mountains, .clouds, .citrus, .arches:
            return .illustrated
        case .littleFlorals, .tambourine, .quilted, .gingham, .checker, .groovy, .dots, .terrazzo:
            return .patterns
        case .goldFoil, .library, .leather, .kraft, .plainCloth:
            return .classic
        }
    }

    /// String Catalog key.
    var name: String {
        switch self {
        case .bouquet: "Bouquet"
        case .botanical: "Botanical"
        case .night: "Night sky"
        case .daisies: "Daisies"
        case .waves: "Waves"
        case .sunrise: "Sunrise"
        case .mountains: "Mountains"
        case .clouds: "Clouds"
        case .citrus: "Citrus"
        case .arches: "Arches"
        case .littleFlorals: "Little florals"
        case .tambourine: "Tambourine"
        case .quilted: "Quilted"
        case .gingham: "Gingham"
        case .checker: "Checker"
        case .groovy: "Groovy"
        case .dots: "Dots"
        case .terrazzo: "Terrazzo"
        case .goldFoil: "Gold foil"
        case .library: "Library"
        case .leather: "Leather"
        case .kraft: "Kraft & tape"
        case .plainCloth: "Plain cloth"
        }
    }

    /// The cloth itself — what the book frames a page in.
    var base: Color { Color(hex: baseHex) }

    fileprivate var baseHex: String {
        switch self {
        case .bouquet: "2E3B35"
        case .botanical: "9DB592"
        case .night: "2F3654"
        case .daisies: "B9D4C2"
        case .waves: "8DBCCB"
        case .sunrise: "F6C9A8"
        case .mountains: "E9DCC3"
        case .clouds: "A9D3EC"
        case .citrus: "F2C35B"
        case .arches: "F3E6D6"
        case .littleFlorals: "F4E6D8"
        case .tambourine: "F2EADB"
        case .quilted: "E8D5B5"
        case .gingham: "F7EFE3"
        case .checker: "F7EFE3"
        case .groovy: "F2E3C6"
        case .dots: "EDBAC5"
        case .terrazzo: "F3ECE0"
        case .goldFoil: "3F6B5C"
        case .library: "2F4A3E"
        case .leather: "7E4F33"
        case .kraft: "C9A47A"
        case .plainCloth: "E9DCC3"
        }
    }

    /// Text that reads on the cloth — for anything drawn over the cover besides its own title.
    var ink: Color {
        switch self {
        case .bouquet, .night, .goldFoil, .library, .leather: Palette.leatherInk
        default: Palette.ink
        }
    }

    /// The design a month starts on. Stepping 7 through 23 designs, consecutive months never
    /// match and every design comes round before any repeats.
    static func forMonth(year: Int, month: Int) -> CoverDesign {
        let all = allCases
        let index = ((year * 12 + month - 1) * 7) % all.count
        return all[(index + all.count) % all.count]
    }
}

// MARK: - Drawing a cover

/// A cover design, drawn at any size: its artwork, then the month's name in the design's own
/// treatment. Everything is laid out in a 120 × 170 cover and scaled to fit.
struct CoverArt: View {
    let design: CoverDesign
    let month: Date

    init(design: CoverDesign, month: Date) {
        self.design = design
        self.month = month
    }

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / CoverCanvas.width
            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in
                    var c = ctx
                    c.scaleBy(x: size.width / CoverCanvas.width, y: size.height / CoverCanvas.height)
                    CoverPainter.paint(design, in: c)
                }
                .frame(width: geo.size.width, height: geo.size.height)

                CoverTitle(design: design, month: month)
                    .frame(width: CoverCanvas.width, height: CoverCanvas.height, alignment: .topLeading)
                    .scaleEffect(scale, anchor: .topLeading)
            }
        }
        .aspectRatio(CoverCanvas.width / CoverCanvas.height, contentMode: .fit)
        .clipped()
        .accessibilityHidden(true)
    }
}

private enum CoverCanvas {
    static let width: CGFloat = 120
    static let height: CGFloat = 170
}

private func hex(_ value: String) -> Color { Color(hex: value) }

// MARK: Artwork

private enum CoverPainter {
    static func paint(_ design: CoverDesign, in ctx: GraphicsContext) {
        var seed: Double = 7
        func rnd() -> Double {
            seed = (seed * 9301 + 49297).truncatingRemainder(dividingBy: 233280)
            return seed / 233280
        }
        let ink = Palette.ink
        ctx.fill(Path(CGRect(x: 0, y: 0, width: 120, height: 170)), with: .color(design.base))

        func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        func polygon(_ points: [(CGFloat, CGFloat)]) -> Path {
            var p = Path()
            p.addLines(points.map { CGPoint(x: $0.0, y: $0.1) })
            p.closeSubpath()
            return p
        }
        /// Draws into a copy of the context moved to (x, y), turned and scaled.
        func at(_ x: CGFloat, _ y: CGFloat, rotate degrees: Double = 0, scale: CGFloat = 1,
                _ draw: (GraphicsContext) -> Void) {
            var c = ctx
            c.translateBy(x: x, y: y)
            c.rotate(by: .degrees(degrees))
            c.scaleBy(x: scale, y: scale)
            draw(c)
        }
        /// An ellipse centred at (x, y) in `c`, turned by `degrees` about the origin first.
        func petal(_ c: GraphicsContext, rotate degrees: Double, cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat,
                   fill: Color, stroke: Color? = nil, width: CGFloat = 0.6) {
            var p = c
            p.rotate(by: .degrees(degrees))
            let shape = Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
            p.fill(shape, with: .color(fill))
            if let stroke { p.stroke(shape, with: .color(stroke), lineWidth: width) }
        }

        switch design {
        case .kraft:
            for _ in 0..<70 {
                let x = rnd() * 120, y = rnd() * 170, r = 0.4 + rnd() * 0.8
                ctx.fill(circle(x, y, r), with: .color(hex("8C6A44").opacity(0.5)))
            }
            at(60, 22, rotate: -9) { c in
                c.fill(Path(CGRect(x: -30, y: -10, width: 64, height: 20)), with: .color(hex("F2B8C6").opacity(0.92)))
                for i in 0..<8 {
                    c.fill(Path(CGRect(x: -27 + CGFloat(i) * 8, y: -10, width: 3, height: 20)),
                           with: .color(.white.opacity(0.45)))
                }
            }

        case .botanical:
            func leaf(_ x: CGFloat, _ y: CGFloat, _ rotation: Double, _ scale: CGFloat) {
                at(x, y, rotate: rotation, scale: scale) { c in
                    var p = Path()
                    p.move(to: .zero)
                    p.addCurve(to: CGPoint(x: 0, y: -54), control1: CGPoint(x: 2, y: -18), control2: CGPoint(x: -2, y: -36))
                    for k in 0..<5 {
                        let yy = -8 - CGFloat(k) * 10
                        p.move(to: CGPoint(x: 0, y: yy))
                        p.addCurve(to: CGPoint(x: 13, y: yy - 14), control1: CGPoint(x: 8, y: yy - 3), control2: CGPoint(x: 12, y: yy - 10))
                        p.addCurve(to: CGPoint(x: 0, y: yy), control1: CGPoint(x: 6, y: yy - 12), control2: CGPoint(x: 1, y: yy - 7))
                        p.move(to: CGPoint(x: 0, y: yy - 4))
                        p.addCurve(to: CGPoint(x: -13, y: yy - 18), control1: CGPoint(x: -8, y: yy - 7), control2: CGPoint(x: -12, y: yy - 14))
                        p.addCurve(to: CGPoint(x: 0, y: yy - 4), control1: CGPoint(x: -6, y: yy - 16), control2: CGPoint(x: -1, y: yy - 11))
                    }
                    c.stroke(p, with: .color(hex("F4F1E6")), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                }
            }
            leaf(30, -4, 165, 1.1); leaf(94, -8, 195, 1.2); leaf(104, 178, -14, 1.2)

        case .night:
            for _ in 0..<38 {
                let x = rnd() * 120, y = rnd() * 120, r = 0.5 + rnd() * 1.1, o = 0.5 + rnd() * 0.5
                ctx.fill(circle(x, y, r), with: .color(hex("F5E7B5").opacity(o)))
            }
            let moon = circle(88, 34, 14).subtracting(circle(95, 29, 11))
            ctx.fill(moon, with: .color(hex("F5E7B5")))
            ctx.fill(polygon([(24, 52), (26, 57), (31, 59), (26, 61), (24, 66), (22, 61), (17, 59), (22, 57)]),
                     with: .color(hex("F5E7B5")))

        case .gingham:
            for i in 0..<9 {
                ctx.fill(Path(CGRect(x: CGFloat(i) * 16, y: 0, width: 8, height: 170)), with: .color(hex("C4483C").opacity(0.32)))
            }
            for i in 0..<11 {
                ctx.fill(Path(CGRect(x: 0, y: CGFloat(i) * 16, width: 120, height: 8)), with: .color(hex("C4483C").opacity(0.32)))
            }

        case .waves:
            let colors = ["F7F3EA", "2F5E7A", "F7F3EA", "2F5E7A", "F7F3EA"]
            for i in 0..<5 {
                let y = 92 + CGFloat(i) * 16
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                var x: CGFloat = 0
                while x <= 120 {
                    p.addQuadCurve(to: CGPoint(x: x + 10, y: y), control: CGPoint(x: x + 5, y: y - 9))
                    p.addQuadCurve(to: CGPoint(x: x + 20, y: y), control: CGPoint(x: x + 15, y: y + 9))
                    x += 20
                }
                p.addLine(to: CGPoint(x: x, y: 170)); p.addLine(to: CGPoint(x: 0, y: 170)); p.closeSubpath()
                ctx.fill(p, with: .color(hex(colors[i])))
                ctx.stroke(p, with: .color(ink), lineWidth: 1)
            }
            ctx.fill(circle(88, 32, 12), with: .color(hex("F7F3EA")))
            ctx.stroke(circle(88, 32, 12), with: .color(ink), lineWidth: 1)

        case .sunrise:
            for i in 0...12 {
                let a = Double.pi * Double(i) / 12
                var p = Path()
                p.move(to: CGPoint(x: 60, y: 150))
                p.addLine(to: CGPoint(x: 60 - cos(a) * 110, y: 150 - sin(a) * 110))
                ctx.stroke(p, with: .color(Palette.amber.opacity(0.45)), lineWidth: 2.4)
            }
            ctx.fill(circle(60, 150, 34), with: .color(Palette.amber))
            ctx.stroke(circle(60, 150, 34), with: .color(ink), lineWidth: 1.5)
            let ground = Path(CGRect(x: 0, y: 150, width: 120, height: 20))
            ctx.fill(ground, with: .color(hex("F7EFE3")))
            ctx.stroke(ground, with: .color(ink), lineWidth: 1.5)

        case .mountains:
            ctx.fill(circle(92, 36, 10), with: .color(Palette.amber.opacity(0.85)))
            let back = polygon([(-5, 120), (32, 62), (58, 100), (80, 72), (125, 128), (125, 170), (-5, 170)])
            ctx.fill(back, with: .color(hex("7E9C8A"))); ctx.stroke(back, with: .color(ink), lineWidth: 1.4)
            ctx.fill(polygon([(32, 62), (24, 74), (30, 72), (34, 78), (40, 70)]), with: .color(Palette.cream))
            ctx.fill(polygon([(80, 72), (74, 80), (80, 79), (84, 84), (88, 82)]), with: .color(Palette.cream))
            let front = polygon([(-5, 140), (22, 112), (48, 136), (74, 110), (125, 150), (125, 170), (-5, 170)])
            ctx.fill(front, with: .color(hex("4F6F62"))); ctx.stroke(front, with: .color(ink), lineWidth: 1.4)

        case .leather:
            let stitch = Path(roundedRect: CGRect(x: 14, y: 10, width: 96, height: 150), cornerRadius: 6)
            ctx.stroke(stitch, with: .color(hex("E9CB7A")), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
            ctx.stroke(polygon([(62, 30), (66, 38), (75, 39), (68, 45), (70, 54), (62, 49), (54, 54), (56, 45), (49, 39), (58, 38)]),
                       with: .color(hex("E9CB7A")), lineWidth: 1.2)

        case .terrazzo:
            let chips = ["F5851F", "90B4DC", "A8CB8C", "C79ACD", "F7C24B", "33261A"]
            for i in 0..<46 {
                let x = rnd() * 120, y = rnd() * 170, s = 2 + rnd() * 5, r = rnd() * 360
                at(x, y, rotate: r) { c in
                    c.fill(polygon([(0, 0), (s, s * 0.3), (s * 0.6, s), (-s * 0.3, s * 0.7)]),
                           with: .color(hex(chips[i % chips.count]).opacity(0.85)))
                }
            }

        case .dots:
            for (row, y) in stride(from: CGFloat(8), to: 176, by: 16).enumerated() {
                for x in stride(from: CGFloat(row % 2 == 0 ? 8 : 16), to: 128, by: 16) {
                    ctx.fill(circle(x, y, 3.2), with: .color(hex("FFF7F2")))
                }
            }

        case .clouds:
            func cloud(_ x: CGFloat, _ y: CGFloat, _ s: CGFloat) {
                at(x, y, scale: s) { c in
                    let shape = circle(-12, -2, 10)
                        .union(circle(2, -8, 13))
                        .union(circle(15, 0, 9))
                        .union(Path(roundedRect: CGRect(x: -22, y: -2, width: 44, height: 10), cornerRadius: 5))
                    c.fill(shape, with: .color(Palette.cream))
                    c.stroke(shape, with: .color(ink), lineWidth: 1.1)
                }
            }
            cloud(36, 34, 1); cloud(88, 64, 0.8); cloud(30, 140, 0.9); cloud(94, 150, 1.1)

        case .citrus:
            func slice(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
                ctx.fill(circle(x, y, r), with: .color(hex("FFF3C4")))
                ctx.stroke(circle(x, y, r), with: .color(ink), lineWidth: 1.2)
                ctx.fill(circle(x, y, r - 3), with: .color(hex("FBE08A")))
                for k in 0..<8 {
                    let a = Double(k) * .pi / 4
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x + cos(a) * (r - 3), y: y + sin(a) * (r - 3)))
                    ctx.stroke(p, with: .color(hex("FFF3C4")), lineWidth: 1.4)
                }
            }
            slice(26, 26, 14); slice(94, 46, 11); slice(30, 146, 12); slice(98, 140, 15)

        case .goldFoil:
            for i in 0..<60 {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: CGFloat(i) * 3)); p.addLine(to: CGPoint(x: 120, y: CGFloat(i) * 3))
                ctx.stroke(p, with: .color(.black.opacity(0.07)), lineWidth: 0.4)
            }

        case .quilted:
            for i in -10..<16 {
                let x = CGFloat(i) * 14
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x + 170, y: 170))
                p.move(to: CGPoint(x: x + 170, y: 0)); p.addLine(to: CGPoint(x: x, y: 170))
                ctx.stroke(p, with: .color(hex("B89A6C")), style: StrokeStyle(lineWidth: 0.9, dash: [2.5, 2]))
            }

        case .littleFlorals:
            let colors = ["C4483C", "5B7FB5", "E7A33E", "B66AA0"]
            for (row, y) in stride(from: CGFloat(6), to: 176, by: 15).enumerated() {
                for x in stride(from: CGFloat(row % 2 == 0 ? 12 : 4), to: 126, by: 16) {
                    let color = hex(colors[Int(rnd() * Double(colors.count)) % colors.count])
                    at(x, y, rotate: floor(rnd() * 70)) { c in
                        for p in 0..<5 {
                            petal(c, rotate: Double(p) * 72, cx: 0, cy: -2.6, rx: 1.5, ry: 2.4, fill: color)
                        }
                        c.fill(circle(0, 0, 1.1), with: .color(hex("F7C24B")))
                        var stem = Path()
                        stem.move(to: CGPoint(x: 2, y: 3))
                        stem.addQuadCurve(to: CGPoint(x: 7, y: 8), control: CGPoint(x: 6, y: 4))
                        c.stroke(stem, with: .color(hex("5E8B4E")), lineWidth: 0.9)
                    }
                }
            }

        case .tambourine:
            for (row, y) in stride(from: CGFloat(18), to: 180, by: 30).enumerated() {
                for x in stride(from: CGFloat(row % 2 == 0 ? 30 : 0), to: 140, by: 60) {
                    for k in 0..<18 {
                        let a = Double(k) * .pi * 2 / 18
                        ctx.fill(circle(x + cos(a) * 11, y + sin(a) * 11, 1.6), with: .color(hex("2F3654")))
                    }
                }
            }

        case .bouquet:
            var stems = Path()
            stems.move(to: CGPoint(x: 60, y: 118))
            stems.addCurve(to: CGPoint(x: 36, y: 56), control1: CGPoint(x: 58, y: 90), control2: CGPoint(x: 44, y: 72))
            stems.move(to: CGPoint(x: 60, y: 118))
            stems.addCurve(to: CGPoint(x: 86, y: 52), control1: CGPoint(x: 62, y: 88), control2: CGPoint(x: 78, y: 70))
            stems.move(to: CGPoint(x: 60, y: 118))
            stems.addCurve(to: CGPoint(x: 60, y: 44), control1: CGPoint(x: 60, y: 92), control2: CGPoint(x: 60, y: 70))
            ctx.stroke(stems, with: .color(hex("8FB27E")), lineWidth: 1.6)
            at(46, 86) { c in petal(c, rotate: -40, cx: 0, cy: 0, rx: 4, ry: 9, fill: hex("8FB27E")) }
            at(74, 84) { c in petal(c, rotate: 40, cx: 0, cy: 0, rx: 4, ry: 9, fill: hex("8FB27E")) }
            func bloom(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ color: String) {
                at(x, y) { c in
                    for k in 0..<8 {
                        petal(c, rotate: Double(k) * 45, cx: 0, cy: -r * 0.55, rx: r * 0.32, ry: r * 0.55, fill: hex(color))
                    }
                    c.fill(circle(0, 0, r * 0.28), with: .color(hex("F7C24B")))
                }
            }
            bloom(36, 52, 16, "E8A0A8"); bloom(86, 48, 15, "F2D2C6"); bloom(60, 38, 18, "E36B5D")
            ctx.fill(polygon([(48, 118), (72, 118), (68, 128), (52, 128)]), with: .color(hex("C9A47A")))

        case .library:
            let gold = hex("E9CB7A")
            ctx.stroke(Path(CGRect(x: 16, y: 12, width: 92, height: 146)), with: .color(gold), lineWidth: 1)
            ctx.stroke(Path(CGRect(x: 20, y: 16, width: 84, height: 138)), with: .color(gold), lineWidth: 0.6)
            for (x, y, sx, sy) in [(20.0, 16.0, 1.0, 1.0), (104, 16, -1, 1), (20, 154, 1, -1), (104, 154, -1, -1)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                var c = ctx
                c.translateBy(x: x, y: y)
                c.scaleBy(x: sx, y: sy)
                var p = Path()
                p.move(to: .zero); p.addQuadCurve(to: CGPoint(x: 12, y: 10), control: CGPoint(x: 10, y: 0))
                p.move(to: .zero); p.addQuadCurve(to: CGPoint(x: 10, y: 12), control: CGPoint(x: 0, y: 10))
                p.move(to: CGPoint(x: 4, y: 4)); p.addLine(to: CGPoint(x: 8, y: 8))
                c.stroke(p, with: .color(gold), lineWidth: 1)
            }
            var heart = Path()
            heart.move(to: CGPoint(x: 62, y: 48))
            heart.addCurve(to: CGPoint(x: 48, y: 56), control1: CGPoint(x: 54, y: 38), control2: CGPoint(x: 42, y: 46))
            heart.addLine(to: CGPoint(x: 62, y: 70))
            heart.addLine(to: CGPoint(x: 76, y: 56))
            heart.addCurve(to: CGPoint(x: 62, y: 48), control1: CGPoint(x: 82, y: 46), control2: CGPoint(x: 70, y: 38))
            ctx.stroke(heart, with: .color(gold), lineWidth: 1.1)

        case .groovy:
            let colors = ["E36B5D", "F5851F", "F2C35B", "8FB27E", "5B8FB5"]
            for i in 0..<5 {
                let y = 100 + CGFloat(i) * 14
                var p = Path()
                p.move(to: CGPoint(x: -10, y: y))
                var x: CGFloat = -10
                while x < 130 {
                    p.addQuadCurve(to: CGPoint(x: x + 15, y: y), control: CGPoint(x: x + 7.5, y: y - 14))
                    p.addQuadCurve(to: CGPoint(x: x + 30, y: y), control: CGPoint(x: x + 22.5, y: y + 14))
                    x += 30
                }
                ctx.stroke(p, with: .color(hex(colors[i])), lineWidth: 12)
            }

        case .daisies:
            func daisy(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
                at(x, y) { c in
                    for k in 0..<12 {
                        petal(c, rotate: Double(k) * 30, cx: 0, cy: -r * 0.6, rx: r * 0.2, ry: r * 0.5,
                              fill: Palette.cream, stroke: ink)
                    }
                    c.fill(circle(0, 0, r * 0.3), with: .color(hex("F7C24B")))
                    c.stroke(circle(0, 0, r * 0.3), with: .color(ink), lineWidth: 0.6)
                }
            }
            daisy(24, 24, 18); daisy(96, 36, 14); daisy(100, 98, 17); daisy(20, 112, 12); daisy(60, 154, 18)

        case .checker:
            for (row, y) in stride(from: CGFloat(0), to: 170, by: 15).enumerated() {
                for x in stride(from: CGFloat(row % 2) * 15, to: 120, by: 30) {
                    ctx.fill(Path(CGRect(x: x, y: y, width: 15, height: 15)), with: .color(hex("A3B6D6")))
                }
            }

        case .arches:
            let colors = ["C97B5A", "E7B48F", "B8A07E", "8F9E7B"]
            for i in 0..<4 {
                let r = 48 - CGFloat(i) * 11
                var p = Path()
                p.move(to: CGPoint(x: 60 - r, y: 170))
                p.addLine(to: CGPoint(x: 60 - r, y: 130))
                p.addArc(center: CGPoint(x: 60, y: 130), radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                p.addLine(to: CGPoint(x: 60 + r, y: 170))
                p.closeSubpath()
                ctx.fill(p, with: .color(hex(colors[i])))
            }
            ctx.fill(circle(92, 72, 9), with: .color(hex("E36B5D").opacity(0.8)))

        case .plainCloth:
            break
        }
    }
}

// MARK: Titles — each design carries the month its own way

private struct CoverTitle: View {
    let design: CoverDesign
    let month: Date

    private var name: String { HDate.monthName(month) }
    private var year: String { HDate.year(month) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            switch design {
            case .waves, .sunrise, .mountains, .groovy, .arches:
                corner(top: true, color: Palette.ink)
            case .night, .bouquet:
                corner(top: false, color: Palette.leatherInk)
            case .leather, .library:
                VStack(spacing: 4) {
                    line(name, Fonts.fixed(16, .heavy), width: 80, color: hex("E9CB7A"))
                    Rectangle().fill(hex("E9CB7A")).frame(width: 38, height: 1)
                    small(year, color: hex("E9CB7A"), tracking: 1.4)
                }
                .position(x: 63, y: 118)
            case .goldFoil:
                VStack(spacing: 6) {
                    Text(verbatim: year).font(Fonts.fixed(34, .heavy)).foregroundStyle(hex("E9CB7A"))
                    small(name.uppercased(), color: hex("E9CB7A"), size: 9, tracking: 2)
                }
                .position(x: 62, y: 86)
            case .checker:
                checkerTitle
            case .kraft:
                line(name, Fonts.serif(14, italic: true), width: 58, color: hex("7A2E3A"))
                    .rotationEffect(.degrees(-9))
                    .position(x: 62, y: 22)
                ZStack {
                    Circle().strokeBorder(hex("7A2E3A"), lineWidth: 1.6)
                    Circle().strokeBorder(hex("7A2E3A"), lineWidth: 0.8).padding(3.5)
                    Text(verbatim: year).font(Fonts.fixed(9, .heavy)).foregroundStyle(hex("7A2E3A"))
                }
                .frame(width: 34, height: 34)
                .rotationEffect(.degrees(-14))
                .opacity(0.85)
                .position(x: 86, y: 128)
            case .gingham:
                RibbonBanner()
                    .fill(hex("C4483C"))
                    .overlay(RibbonBanner().stroke(Palette.ink, lineWidth: 1.4))
                    .frame(width: 124, height: 28)
                    .position(x: 60, y: 90)
                line(name, Fonts.serif(16, italic: true), width: 92, color: hex("FFF3E8"))
                    .position(x: 62, y: 90)
                small(year, color: hex("7A2E2A"), tracking: 2).position(x: 62, y: 116)
            case .daisies:
                ZStack {
                    ForEach(0..<16, id: \.self) { k in
                        Ellipse().fill(Palette.cream)
                            .overlay(Ellipse().stroke(Palette.ink, lineWidth: 0.9))
                            .frame(width: 14, height: 34)
                            .offset(y: -30)
                            .rotationEffect(.degrees(Double(k) * 22.5))
                    }
                    Circle().fill(hex("F7C24B")).overlay(Circle().stroke(Palette.ink, lineWidth: 1.2)).frame(width: 44, height: 44)
                    VStack(spacing: 1) {
                        line(name, Fonts.fixed(10, .heavy), width: 36, color: Palette.ink)
                        small(year, color: hex("5A3D12"), size: 5.5, tracking: 1)
                    }
                }
                .position(x: 60, y: 92)
            case .botanical:
                VStack(spacing: 4) {
                    line(name, Fonts.serif(22, italic: true), width: 92, color: Palette.cream)
                    small(year, color: hex("F4F1E6"), size: 6.5, tracking: 3)
                }
                .position(x: 62, y: 98)
            case .littleFlorals:
                ZStack {
                    TornStrip().fill(Palette.cream).overlay(TornStrip().stroke(Palette.ink, lineWidth: 0.8))
                        .frame(width: 130, height: 30)
                    VStack(spacing: 0) {
                        line(name, Fonts.serif(17), width: 96, color: Palette.ink)
                        small(year, color: hex("C4483C"), size: 5.5, tracking: 2)
                    }
                }
                .rotationEffect(.degrees(-6))
                .position(x: 62, y: 92)
            case .tambourine:
                ZStack {
                    Circle().fill(hex("F2EADB")).frame(width: 64, height: 64)
                    ForEach(0..<34, id: \.self) { k in
                        Circle().fill(hex("2F3654")).frame(width: 5.6, height: 5.6)
                            .offset(y: -36)
                            .rotationEffect(.degrees(Double(k) * 360 / 34))
                    }
                    VStack(spacing: 2) {
                        line(name, Fonts.serif(15, italic: true), width: 56, color: hex("2F3654"))
                        small(year, color: hex("2F3654"), size: 5.5, tracking: 1.5)
                    }
                }
                .position(x: 62, y: 90)
            case .quilted:
                VStack(spacing: 6) {
                    stitch
                    line(name, Fonts.fixed(20, .heavy), width: 96, color: hex("9E5B3C"))
                    stitch
                    small(year, color: hex("7A563A"), size: 6.5, tracking: 2)
                }
                .position(x: 62, y: 96)
            case .dots:
                ZStack {
                    line(name, Fonts.fixed(22, .heavy), width: 100, color: hex("B76F82")).offset(x: 1.5, y: 1.5)
                    line(name, Fonts.fixed(22, .heavy), width: 100, color: hex("FFF7F2"))
                }
                .position(x: 62, y: 90)
                small(year, color: hex("7A3B4C"), tracking: 2).position(x: 62, y: 108)
            case .citrus:
                line(name, Fonts.serif(22, italic: true), width: 96, color: hex("2F5E3A")).position(x: 62, y: 92)
                small(year, color: Palette.ink, size: 6.5, tracking: 0.5).position(x: 98, y: 140)
            case .clouds:
                ZStack {
                    ForEach(Array(Self.outline.enumerated()), id: \.offset) { _, o in
                        line(name, Fonts.fixed(20, .heavy), width: 92, color: Palette.ink).offset(x: o.width, y: o.height)
                    }
                    line(name, Fonts.fixed(20, .heavy), width: 92, color: Palette.cream)
                }
                .position(x: 62, y: 90)
                ForEach(0..<7, id: \.self) { d in
                    let r = 2.6 - CGFloat(d) * 0.3
                    Circle().fill(Palette.cream).overlay(Circle().stroke(Palette.ink, lineWidth: 0.6))
                        .frame(width: r * 2, height: r * 2)
                        .position(x: 14 + CGFloat(d) * 7, y: 112 + sin(CGFloat(d)) * 2)
                }
                small(year, color: Palette.ink, tracking: 2).position(x: 94, y: 112)
            case .plainCloth:
                ZStack {
                    line(name, Fonts.serif(20), width: 90, color: .white.opacity(0.55)).offset(x: 0.6, y: 0.6)
                    line(name, Fonts.serif(20), width: 90, color: hex("B9A37F"))
                }
                .position(x: 62, y: 84)
                small(year, color: hex("B9A37F"), size: 6.5, tracking: 3).position(x: 62, y: 100)
            case .terrazzo:
                let chips = ["F5851F", "5B7FB5", "5E8B4E", "B66AA0", "E7A33E", "33261A"]
                Array(name).enumerated().reduce(Text(verbatim: "")) { text, item in
                    text + Text(verbatim: String(item.element)).foregroundStyle(hex(chips[item.offset % chips.count]))
                }
                .font(Fonts.fixed(22, .heavy))
                .lineLimit(1).minimumScaleFactor(0.3)
                .frame(width: 100)
                .position(x: 62, y: 90)
                small(year, color: Palette.ink, tracking: 2).position(x: 62, y: 108)
            }
        }
    }

    // Year (or a month's caps) set small and spaced.
    private func small(_ text: String, color: Color, size: CGFloat = 7, tracking: CGFloat = 1.2) -> some View {
        Text(verbatim: text).font(Fonts.fixed(size, .heavy)).tracking(tracking).foregroundStyle(color)
            .lineLimit(1).fixedSize()
    }

    // A one-line title that shrinks to fit `width`.
    private func line(_ text: String, _ font: Font, width: CGFloat, color: Color) -> some View {
        Text(verbatim: text).font(font).foregroundStyle(color)
            .lineLimit(1).minimumScaleFactor(0.3)
            .frame(width: width)
    }

    /// Year over month at the top-left (in the sky) or bottom-left (under the art).
    private func corner(top: Bool, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            small(year, color: color)
            Text(verbatim: name).font(Fonts.fixed(17, .heavy)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.4)
        }
        .frame(width: 96, alignment: .leading)
        .offset(x: 15, y: top ? 26 : 128)
    }

    /// Each letter in its own square of the board.
    private var checkerTitle: some View {
        let letters = Array(name.uppercased())
        let square = min(13, 104 / CGFloat(max(letters.count, 1)))
        return VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(Array(letters.enumerated()), id: \.offset) { k, ch in
                    let dark = k % 2 == 0
                    Text(verbatim: String(ch))
                        .font(Fonts.fixed(square * 0.72, .heavy))
                        .foregroundStyle(dark ? Palette.cream : Palette.ink)
                        .frame(width: square, height: square)
                        .background(dark ? Palette.ink : Palette.cream)
                        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 1))
                }
            }
            small(year, color: Palette.ink, tracking: 2)
        }
        .position(x: 62, y: 86)
    }

    private var stitch: some View {
        Line().stroke(hex("9E5B3C"), style: StrokeStyle(lineWidth: 1.3, dash: [3, 2.5]))
            .frame(width: 88, height: 1.3)
    }

    private static let outline: [CGSize] = [
        CGSize(width: -1, height: -1), CGSize(width: 1, height: -1), CGSize(width: -1, height: 1),
        CGSize(width: 1, height: 1), CGSize(width: 0, height: -1.4), CGSize(width: 0, height: 1.4),
        CGSize(width: -1.4, height: 0), CGSize(width: 1.4, height: 0)
    ]
}

/// A ribbon with swallowtail ends, laid across the cover.
private struct RibbonBanner: Shape {
    func path(in rect: CGRect) -> Path {
        let notch = rect.height / 2, tail = rect.width * 0.065
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - tail, y: rect.minY + notch))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + tail, y: rect.minY + notch))
        p.closeSubpath()
        return p
    }
}

/// A strip of paper with torn top and bottom edges.
private struct TornStrip: Shape {
    func path(in rect: CGRect) -> Path {
        let top: [CGFloat] = [0, -2, 1, -2, 0, -3, 0, -2, 0, -3, -1, -2, 0, -1]
        let bottom: [CGFloat] = [0, 2, -1, 2, 0, 3, 1, 2, -1, 2, 0, 1, 2, 0]
        let step = rect.width / CGFloat(top.count - 1)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + 2))
        for (i, d) in top.enumerated() { p.addLine(to: CGPoint(x: rect.minX + CGFloat(i) * step, y: rect.minY + 2 + d)) }
        for (i, d) in bottom.enumerated().reversed() {
            p.addLine(to: CGPoint(x: rect.minX + CGFloat(i) * step, y: rect.maxY - 2 + d))
        }
        p.closeSubpath()
        return p
    }
}

/// A horizontal line across its frame.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
