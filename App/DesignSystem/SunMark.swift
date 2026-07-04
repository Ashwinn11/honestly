import SwiftUI

/// The sunrise mark, in the "Hand-drawn Warmth" style: eight **black ink rays** around a **gold disc
/// with a black outline**. Parametric so it serves as the brand glyph, the gratitude sun, the
/// notification icon and the streak/score flourish.
///
/// - `rays` / `disc`: toggle either element (celebration halo = rays only; entry-row score = disc only).
/// - `muted`: the faint empty-gratitude state — grey rays + hollow grey ring, no fill.
struct SunMark: View {
    var size: CGFloat = 28
    var rays: Bool = true
    var disc: Bool = true
    var muted: Bool = false
    var tint: Color? = nil          // disc fill override (e.g. cream disc on an amber card)

    private static let rayLines: [[CGFloat]] = [
        [50, 5, 50, 17], [50, 83, 50, 95], [5, 50, 17, 50], [83, 50, 95, 50],
        [19, 19, 27.5, 27.5], [72.5, 72.5, 81, 81], [81, 19, 72.5, 27.5], [27.5, 72.5, 19, 81],
    ]

    /// Ink weight (in the 100-unit viewBox) — thinner as the mark grows, matching the HTML.
    private var lineUnits: CGFloat {
        switch size {
        case ..<30:  return 7
        case ..<60:  return 6
        case ..<95:  return 5
        default:     return 4.5
        }
    }

    var body: some View {
        Canvas { ctx, cs in
            let s = cs.width / 100
            let lw = lineUnits * s
            let inkColor = muted ? Palette.ink.opacity(0.32) : Palette.ink
            let discFill = tint ?? Palette.sunDisc

            if rays {
                var p = Path()
                for l in Self.rayLines {
                    p.move(to: CGPoint(x: l[0] * s, y: l[1] * s))
                    p.addLine(to: CGPoint(x: l[2] * s, y: l[3] * s))
                }
                ctx.stroke(p, with: .color(inkColor),
                           style: StrokeStyle(lineWidth: lw, lineCap: .round))
            }

            if disc {
                let d = Path(ellipseIn: CGRect(x: 30 * s, y: 30 * s, width: 40 * s, height: 40 * s))
                if muted {
                    ctx.stroke(d, with: .color(inkColor), lineWidth: lw)
                } else {
                    ctx.fill(d, with: .color(discFill))
                    ctx.stroke(d, with: .color(Palette.ink), lineWidth: lw)
                }
            }
        }
        .frame(width: size, height: size)
    }
}
