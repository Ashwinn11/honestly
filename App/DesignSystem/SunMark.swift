import SwiftUI

/// The sunrise mark — a disc with eight rays. Ported 1:1 from `SunMark.dc.html`
/// (viewBox 0 0 100 100, disc r=19 at center, 8 rays, stroke width 7). Parametric so it
/// serves as the brand glyph, the gratitude sun, notification icon, and streak flourish.
///
/// `fill == nil` draws a hollow ring (the unlit gratitude sun) stroked in `stroke`.
struct SunMark: View {
    var size: CGFloat = 28
    var stroke: Color = Palette.amber
    var fill: Color? = Palette.amberLight
    var rays: Bool = true

    private static let rayLines: [[CGFloat]] = [
        [50, 5, 50, 17], [50, 83, 50, 95], [5, 50, 17, 50], [83, 50, 95, 50],
        [19, 19, 27.5, 27.5], [72.5, 72.5, 81, 81], [81, 19, 72.5, 27.5], [27.5, 72.5, 19, 81],
    ]

    var body: some View {
        Canvas { ctx, cs in
            let s = cs.width / 100
            let lw = 7 * s

            if rays {
                var p = Path()
                for l in Self.rayLines {
                    p.move(to: CGPoint(x: l[0] * s, y: l[1] * s))
                    p.addLine(to: CGPoint(x: l[2] * s, y: l[3] * s))
                }
                ctx.stroke(p, with: .color(stroke),
                           style: StrokeStyle(lineWidth: lw, lineCap: .round))
            }

            let disc = Path(ellipseIn: CGRect(x: 31 * s, y: 31 * s, width: 38 * s, height: 38 * s))
            if let fill {
                ctx.fill(disc, with: .color(fill))
            } else {
                ctx.stroke(disc, with: .color(stroke), lineWidth: lw)
            }
        }
        .frame(width: size, height: size)
    }
}
