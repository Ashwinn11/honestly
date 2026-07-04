import SwiftUI

struct MoodFace: View {
    let mood: Int
    var size: CGFloat = 44

    init(mood: Int, size: CGFloat = 44) { self.mood = min(max(mood, 0), 4); self.size = size }
    init(_ mood: Mood, size: CGFloat = 44) { self.init(mood: mood.rawValue, size: size) }

    var body: some View {
        Canvas { ctx, cs in
            let s = cs.width / 100
            let face = Palette.mood(mood)
            let ink = Palette.moodInk(mood)
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

            let disc = Path(ellipseIn: CGRect(x: 1 * s, y: 1 * s, width: 98 * s, height: 98 * s))
            ctx.fill(disc, with: .color(face))
            ctx.stroke(disc, with: .color(ink.opacity(0.16)), lineWidth: 2 * s)

            switch mood {
            case 0: // Happy — dot eyes, wide smile
                dot(31, 38); dot(69, 38)
                stroke({ $0.move(to: pt(28, 63)); $0.addQuadCurve(to: pt(72, 63), control: pt(50, 83)) })

            case 1: // Confused — asymmetric raised brows, dot eyes, tilted flat mouth
                stroke({ $0.move(to: pt(22, 28)); $0.addQuadCurve(to: pt(40, 28), control: pt(31, 25)) }, 4.5)
                stroke({ $0.move(to: pt(60, 18)); $0.addQuadCurve(to: pt(78, 18), control: pt(69, 13)) }, 4.5)
                dot(31, 39); dot(69, 39)
                stroke({ $0.move(to: pt(36, 70)); $0.addLine(to: pt(64, 63)) }, 4.5)

            case 2: // Sad — worried slanted brows, dot eyes, frown
                stroke({ $0.move(to: pt(23, 26)); $0.addLine(to: pt(39, 20)) }, 4.5)
                stroke({ $0.move(to: pt(61, 20)); $0.addLine(to: pt(77, 26)) }, 4.5)
                dot(31, 38); dot(69, 38)
                stroke({ $0.move(to: pt(28, 75)); $0.addQuadCurve(to: pt(72, 75), control: pt(50, 59)) })

            case 3: // Awful — winced >< eyes, squiggly mouth
                stroke({ $0.move(to: pt(20, 27)); $0.addLine(to: pt(32, 35)); $0.addLine(to: pt(20, 43)) }, 4.5)
                stroke({ $0.move(to: pt(80, 27)); $0.addLine(to: pt(68, 35)); $0.addLine(to: pt(80, 43)) }, 4.5)
                stroke({
                    $0.move(to: pt(24, 71))
                    $0.addQuadCurve(to: pt(37, 71), control: pt(30.5, 63))
                    $0.addQuadCurve(to: pt(50, 71), control: pt(43.5, 79))
                    $0.addQuadCurve(to: pt(63, 71), control: pt(56.5, 63))
                    $0.addQuadCurve(to: pt(76, 71), control: pt(69.5, 79))
                }, 4.5)

            default: // 4 Cry — worried brows, two tears, frown (eyes closed)
                stroke({ $0.move(to: pt(21, 39)); $0.addQuadCurve(to: pt(39, 39), control: pt(30, 29)) }, 4.5)
                stroke({ $0.move(to: pt(61, 39)); $0.addQuadCurve(to: pt(79, 39), control: pt(70, 29)) }, 4.5)
                let tear = Color(hex: "5B8FD6")
                for cx in [CGFloat(30), CGFloat(70)] {
                    var t = Path()
                    t.move(to: pt(cx, 46))
                    t.addCurve(to: pt(cx, 67), control1: pt(cx - 6, 56), control2: pt(cx - 7, 65))
                    t.addCurve(to: pt(cx, 46), control1: pt(cx + 7, 65), control2: pt(cx + 6, 56))
                    t.closeSubpath()
                    ctx.fill(t, with: .color(tear))
                }
                stroke({ $0.move(to: pt(34, 79)); $0.addQuadCurve(to: pt(66, 79), control: pt(50, 66)) })
            }
        }
        .frame(width: size, height: size)
    }
}
