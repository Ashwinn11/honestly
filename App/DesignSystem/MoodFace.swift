import SwiftUI

/// The mood face — a gold/green/blue/purple disc with a **black ink outline** and hand-drawn
/// eyes + mouth, ported 1:1 from the "Hand-drawn Warmth" redesign (viewBox 0 0 100 100, disc r48,
/// outline 3.5). Small instances (calendar, home, history) use the simple faces; the ritual mood
/// picker passes `expressive: true` for the richer awful (`><` eyes + squiggle) and cry (tears) faces.
struct MoodFace: View {
    let mood: Int
    var size: CGFloat = 44
    var expressive: Bool = false

    init(mood: Int, size: CGFloat = 44, expressive: Bool = false) {
        self.mood = min(max(mood, 0), 4); self.size = size; self.expressive = expressive
    }

    var body: some View {
        Canvas { ctx, cs in
            let s = cs.width / 100
            let face = Palette.mood(mood)
            let ink = Palette.moodInk(mood)
            let outline = Palette.ink
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat = 5.5) {
                ctx.fill(Path(ellipseIn: CGRect(x: (x - r) * s, y: (y - r) * s,
                                                width: r * 2 * s, height: r * 2 * s)), with: .color(ink))
            }
            func stroke(_ build: (inout Path) -> Void, _ w: CGFloat = 5, _ color: Color? = nil) {
                var p = Path(); build(&p)
                ctx.stroke(p, with: .color(color ?? ink),
                           style: StrokeStyle(lineWidth: w * s, lineCap: .round, lineJoin: .round))
            }

            // Disc: colored fill + bold black ink outline (3.5 on a 100 viewBox).
            let disc = Path(ellipseIn: CGRect(x: 2 * s, y: 2 * s, width: 96 * s, height: 96 * s))
            ctx.fill(disc, with: .color(face))
            ctx.stroke(disc, with: .color(outline), lineWidth: 3.5 * s)

            switch mood {
            case 0: // Happy — dot eyes, wide smile
                dot(31, 38); dot(69, 38)
                stroke({ $0.move(to: pt(28, 63)); $0.addQuadCurve(to: pt(72, 63), control: pt(50, 83)) })

            case 1: // Confused — dot eyes, short tilted mouth
                dot(31, 39); dot(69, 39)
                stroke({ $0.move(to: pt(36, 70)); $0.addLine(to: pt(64, 63)) }, 4.5)

            case 2: // Sad — dot eyes, frown
                dot(31, 38); dot(69, 38)
                stroke({ $0.move(to: pt(28, 75)); $0.addQuadCurve(to: pt(72, 75), control: pt(50, 59)) })

            case 3 where expressive: // Awful (picker) — winced >< eyes, big squiggly mouth
                stroke({ $0.move(to: pt(20, 27)); $0.addLine(to: pt(32, 35)); $0.addLine(to: pt(20, 43)) }, 4.5)
                stroke({ $0.move(to: pt(80, 27)); $0.addLine(to: pt(68, 35)); $0.addLine(to: pt(80, 43)) }, 4.5)
                stroke({
                    $0.move(to: pt(24, 71))
                    $0.addQuadCurve(to: pt(37, 71), control: pt(30.5, 63))
                    $0.addQuadCurve(to: pt(50, 71), control: pt(43.5, 79))
                    $0.addQuadCurve(to: pt(63, 71), control: pt(56.5, 63))
                    $0.addQuadCurve(to: pt(76, 71), control: pt(69.5, 79))
                }, 4.5)

            case 3: // Awful (small) — dot eyes, gentle wave mouth
                dot(31, 39); dot(69, 39)
                stroke({
                    $0.move(to: pt(30, 72))
                    $0.addQuadCurve(to: pt(50, 71), control: pt(40, 64))
                    $0.addQuadCurve(to: pt(70, 70), control: pt(60, 78))
                }, 4.5)

            default: // Cry — raised worried brows + frown; expressive adds two tears
                stroke({ $0.move(to: pt(21, 39)); $0.addQuadCurve(to: pt(39, 39), control: pt(30, 29)) }, 4.5)
                stroke({ $0.move(to: pt(61, 39)); $0.addQuadCurve(to: pt(79, 39), control: pt(70, 29)) }, 4.5)
                if expressive {
                    let tear = Color(hex: "5B8FD6")
                    for cx in [CGFloat(30), CGFloat(70)] {
                        var t = Path()
                        t.move(to: pt(cx, 46))
                        t.addCurve(to: pt(cx, 67), control1: pt(cx - 6, 56), control2: pt(cx - 7, 65))
                        t.addCurve(to: pt(cx, 46), control1: pt(cx + 7, 65), control2: pt(cx + 6, 56))
                        t.closeSubpath()
                        ctx.fill(t, with: .color(tear))
                    }
                }
                stroke({ $0.move(to: pt(34, 79)); $0.addQuadCurve(to: pt(66, 79), control: pt(50, 66)) })
            }
        }
        .frame(width: size, height: size)
    }
}
