import SwiftUI

// MARK: - Tactile shadow (the redesign's hard, zero-blur ink offset)

extension View {
    /// The signature "drawn" drop (`box-shadow: 0 Ypx 0 ink`): a solid ink ledge tucked *behind* the
    /// view and offset straight down, so it peeks out only at the bottom. Drawn as an offset
    /// rounded-rect background — NOT `.shadow`, which would also ghost the text/label on top.
    func tactile(_ y: CGFloat = 4, cornerRadius: CGFloat = 16, color: Color = Palette.ink) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(y > 0 ? color : Color.clear)
                .offset(y: y)
        )
    }
}

/// A soft radial glow that fades to transparent — the redesign's warm halo behind suns, big numbers
/// and headings (`radial-gradient(circle, rgba(...), transparent 68%)`). Never a hard-edged disc.
struct SoftGlow: View {
    var color: Color = Palette.sunDisc
    var opacity: Double = 0.2
    var size: CGFloat = 260
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(opacity), color.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: size * 0.34))
            .frame(width: size, height: size)
            .allowsHitTesting(false)
    }
}

// MARK: - Squiggle underline (hand-drawn stroke beneath a heading)

struct Squiggle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, baseY = r.midY, amp = r.height * 0.42
        let seg = w / 3
        p.move(to: CGPoint(x: r.minX + w * 0.02, y: baseY + amp * 0.4))
        p.addQuadCurve(to: CGPoint(x: r.minX + seg, y: baseY),
                       control: CGPoint(x: r.minX + seg * 0.5, y: baseY - amp))
        p.addQuadCurve(to: CGPoint(x: r.minX + seg * 2, y: baseY),
                       control: CGPoint(x: r.minX + seg * 1.5, y: baseY + amp))
        p.addQuadCurve(to: CGPoint(x: r.maxX - w * 0.02, y: baseY - amp * 0.2),
                       control: CGPoint(x: r.minX + seg * 2.5, y: baseY - amp))
        return p
    }
}

extension View {
    /// Adds a warm hand-drawn squiggle just beneath the content (sized to the content width),
    /// matching the underlines the redesign draws under section headings.
    func underlineSquiggle(_ color: Color = Palette.amber, weight: CGFloat = 4, height: CGFloat = 8) -> some View {
        overlay(alignment: .bottomLeading) {
            Squiggle()
                .stroke(color, style: StrokeStyle(lineWidth: weight, lineCap: .round, lineJoin: .round))
                .frame(height: height)
                .offset(y: height + 2)          // sit just below the text baseline
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Floating decor glyphs (filled + black-outlined, from the HTML)

/// A decor glyph, defined in a 24-unit SVG-style viewBox and scaled to fit its frame.
struct GlyphShape: Shape {
    enum Kind { case sparkle, heart, star, flame, moon }
    let kind: Kind

    func path(in r: CGRect) -> Path {
        var p = Path()
        switch kind {
        case .sparkle:
            p.move(to: .init(x: 12, y: 1))
            p.addCurve(to: .init(x: 23, y: 12), control1: .init(x: 13, y: 8), control2: .init(x: 16, y: 11))
            p.addCurve(to: .init(x: 12, y: 23), control1: .init(x: 16, y: 13), control2: .init(x: 13, y: 16))
            p.addCurve(to: .init(x: 1, y: 12), control1: .init(x: 11, y: 16), control2: .init(x: 8, y: 13))
            p.addCurve(to: .init(x: 12, y: 1), control1: .init(x: 8, y: 11), control2: .init(x: 11, y: 8))
            p.closeSubpath()
        case .heart:
            p.move(to: .init(x: 12, y: 21))
            p.addCurve(to: .init(x: 5, y: 6), control1: .init(x: 4, y: 14), control2: .init(x: 2, y: 9))
            p.addCurve(to: .init(x: 12, y: 8), control1: .init(x: 8, y: 3), control2: .init(x: 11, y: 5))
            p.addCurve(to: .init(x: 19, y: 6), control1: .init(x: 13, y: 5), control2: .init(x: 16, y: 3))
            p.addCurve(to: .init(x: 12, y: 21), control1: .init(x: 22, y: 9), control2: .init(x: 20, y: 14))
            p.closeSubpath()
        case .star:
            let pts: [(CGFloat, CGFloat)] = [(12,2),(15,9),(22,9),(16,14),(18,21),(12,17),(6,21),(8,14),(2,9),(9,9)]
            p.move(to: .init(x: pts[0].0, y: pts[0].1))
            for pt in pts.dropFirst() { p.addLine(to: .init(x: pt.0, y: pt.1)) }
            p.closeSubpath()
        case .flame:
            p.move(to: .init(x: 12, y: 2))
            p.addCurve(to: .init(x: 18, y: 13), control1: .init(x: 14, y: 7), control2: .init(x: 18, y: 8))
            p.addCurve(to: .init(x: 6, y: 13), control1: .init(x: 18, y: 20), control2: .init(x: 6, y: 20))
            p.addCurve(to: .init(x: 9.5, y: 6.5), control1: .init(x: 6, y: 9), control2: .init(x: 8, y: 9))
            p.addCurve(to: .init(x: 12, y: 8), control1: .init(x: 11, y: 8), control2: .init(x: 11, y: 8))
            p.addCurve(to: .init(x: 12, y: 2), control1: .init(x: 12, y: 5), control2: .init(x: 12, y: 4))
            p.closeSubpath()
        case .moon:
            p.addArc(center: .init(x: 11, y: 12), radius: 9.5,
                     startAngle: .degrees(70), endAngle: .degrees(290), clockwise: false)
            p.addArc(center: .init(x: 16, y: 11), radius: 8,
                     startAngle: .degrees(250), endAngle: .degrees(110), clockwise: true)
            p.closeSubpath()
        }
        let k = min(r.width, r.height) / 24
        return p.applying(CGAffineTransform(scaleX: k, y: k))
            .applying(CGAffineTransform(translationX: r.minX, y: r.minY))
    }
}

/// A filled decor glyph with a black ink outline — the reusable floating-decor building block.
struct InkGlyph: View {
    let kind: GlyphShape.Kind
    var size: CGFloat
    var fill: Color
    var outline: Color = Palette.ink
    var lineWidth: CGFloat = 1.5

    var body: some View {
        let shape = GlyphShape(kind: kind)
        shape.fill(fill)
            .overlay(shape.stroke(outline, style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round)))
            .frame(width: size, height: size)
    }
}
