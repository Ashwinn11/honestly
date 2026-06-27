import SwiftUI

// ART: Placeholder character mascots used as decorative friends.
// Replace each case's drawing with supplied art; keep Mascot(kind:size:) API.

enum MascotKind {
    case sun, cloud, flower, mushroom, clover
}

struct Mascot: View {
    let kind: MascotKind
    var size: CGFloat = 48

    private var s: CGFloat { size / 48 }

    var body: some View {
        ZStack {
            switch kind {
            case .sun:      sun
            case .cloud:    cloud
            case .flower:   flower
            case .mushroom: mushroom
            case .clover:   clover
            }
        }
        .frame(width: size, height: size)
    }

    private var sun: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Capsule()
                    .fill(Theme.ink)
                    .frame(width: 2.5 * s, height: 8 * s)
                    .offset(y: -22 * s)
                    .rotationEffect(.degrees(Double(i) / 8 * 360))
            }
            Circle()
                .fill(Theme.happy)
                .overlay(Circle().stroke(Theme.ink, lineWidth: 2.5 * s))
                .frame(width: 28 * s, height: 28 * s)
            tinyFace
        }
    }

    private var cloud: some View {
        ZStack {
            Capsule()
                .fill(Theme.cry)
                .overlay(Capsule().stroke(Theme.ink, lineWidth: 2.5 * s))
                .frame(width: 38 * s, height: 24 * s)
            tinyFace
        }
    }

    private var flower: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Ellipse()
                    .fill(Theme.sad)
                    .overlay(Ellipse().stroke(Theme.ink, lineWidth: 2 * s))
                    .frame(width: 12 * s, height: 18 * s)
                    .offset(y: -12 * s)
                    .rotationEffect(.degrees(Double(i) / 6 * 360))
            }
            Circle()
                .fill(Theme.happy)
                .overlay(Circle().stroke(Theme.ink, lineWidth: 2 * s))
                .frame(width: 16 * s, height: 16 * s)
        }
    }

    private var mushroom: some View {
        VStack(spacing: -2 * s) {
            Arc180()
                .fill(Theme.confused)
                .overlay(Arc180().stroke(Theme.ink, lineWidth: 2.5 * s))
                .frame(width: 36 * s, height: 22 * s)
            RoundedRectangle(cornerRadius: 4 * s)
                .fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 4 * s).stroke(Theme.ink, lineWidth: 2.5 * s))
                .frame(width: 16 * s, height: 16 * s)
        }
    }

    private var clover: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(Theme.confused)
                    .overlay(Circle().stroke(Theme.ink, lineWidth: 2 * s))
                    .frame(width: 18 * s, height: 18 * s)
                    .offset(y: -9 * s)
                    .rotationEffect(.degrees(Double(i) / 4 * 360 + 45))
            }
        }
    }

    private var tinyFace: some View {
        HStack(spacing: 6 * s) {
            Circle().fill(Theme.ink).frame(width: 2.5 * s, height: 2.5 * s)
            Circle().fill(Theme.ink).frame(width: 2.5 * s, height: 2.5 * s)
        }
    }
}

/// Half-dome for the mushroom cap.
private struct Arc180: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY),
                 radius: rect.width / 2,
                 startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        p.closeSubpath()
        return p
    }
}
