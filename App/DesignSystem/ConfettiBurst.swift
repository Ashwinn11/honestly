import SwiftUI

struct ConfettiBurst: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date? = nil
    @State private var finished = false

    private static let palette: [Color] = Palette.moods + [.white]
    private static let pieceCount = 96
    private static let gravity: CGFloat = 1350
    private static let life: TimeInterval = 3.6

    var body: some View {
        TimelineView(.animation(paused: finished || reduceMotion)) { tl in
            Canvas { ctx, size in
                guard let start else { return }
                let t = tl.date.timeIntervalSince(start)
                for i in 0..<Self.pieceCount { draw(piece: i, at: t, in: size, ctx: ctx) }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            start = Date()
            Task { try? await Task.sleep(for: .seconds(Self.life)); finished = true }
        }
    }

    private func rnd(_ seed: Int, _ salt: Int) -> CGFloat {
        let x = sin(Double(seed) * 12.9898 + Double(salt) * 78.233) * 43758.5453
        return CGFloat(x - x.rounded(.down))
    }

    private func draw(piece i: Int, at t: TimeInterval, in size: CGSize, ctx: GraphicsContext) {
        let leftPopper = i % 2 == 0
        let delay = Double(rnd(i, 1)) * 0.35 + (leftPopper ? 0 : 0.12)
        let te = CGFloat(t - delay)
        guard te > 0 else { return }

        let origin = CGPoint(x: leftPopper ? size.width * 0.05 : size.width * 0.95, y: size.height + 10)
        let baseAngle: CGFloat = leftPopper ? -1.20 : -1.94        // radians; ±~69° from vertical
        let angle = baseAngle + (rnd(i, 2) - 0.5) * 0.66
        let speed = 950 + rnd(i, 3) * 650
        let vx = cos(angle) * speed, vy = sin(angle) * speed

        let flutter = sin(te * (3 + rnd(i, 4) * 3) + rnd(i, 5) * 6) * 26 * min(te, 1.4)
        let x = origin.x + vx * te + flutter
        let y = origin.y + vy * te + 0.5 * Self.gravity * te * te
        guard y < size.height + 30 else { return }

        let sz = 7 + rnd(i, 6) * 9
        let rot = Double(rnd(i, 7)) * 720 + Double(te) * Double(rnd(i, 8) - 0.5) * 900
        let color = Self.palette[i % Self.palette.count]
        let isCircle = rnd(i, 9) < 0.4
        let fade = max(0, min(1, (Self.life - Double(te)) / 0.6))

        var c = ctx
        c.translateBy(x: x, y: y)
        c.rotate(by: .degrees(rot))
        c.opacity = fade
        let shape = isCircle
            ? Path(ellipseIn: CGRect(x: -sz / 2, y: -sz / 2, width: sz, height: sz))
            : Path(roundedRect: CGRect(x: -sz / 2, y: -sz * 0.3, width: sz, height: sz * 0.6), cornerRadius: 1.5)
        c.fill(shape, with: .color(color))
    }
}
