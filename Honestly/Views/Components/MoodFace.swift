import SwiftUI

// ART: Placeholder mood faces. Replace the inner `face` drawing with the
// supplied illustrations. Public API (MoodFace(mood:size:)) must stay stable.

struct MoodFace: View {
    let mood: Mood
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Circle()
                .fill(mood.color)
                .overlay(Circle().stroke(Theme.ink, lineWidth: max(2, AppLayout.s(size) * 0.045)))
            face
        }
        .frame(width: AppLayout.s(size), height: AppLayout.s(size))
    }

    private var s: CGFloat { AppLayout.s(size) / 120 }

    @ViewBuilder private var face: some View {
        switch mood {
        case .happy:    happyFace
        case .confused: confusedFace
        case .sad:      sadFace
        case .awful:    awfulFace
        case .cry:      cryFace
        }
    }

    // Simple, recognizable expressions (stand-ins for final art).

    private var happyFace: some View {
        ZStack {
            eyes(curveUp: true)
            Arc(start: .degrees(20), end: .degrees(160), clockwise: false)
                .stroke(Theme.ink, style: .init(lineWidth: 5 * s, lineCap: .round))
                .frame(width: 46 * s, height: 40 * s)
                .offset(y: 18 * s)
        }
    }

    private var confusedFace: some View {
        ZStack {
            dotEyes
            Capsule()
                .fill(Theme.ink)
                .frame(width: 26 * s, height: 4.5 * s)
                .rotationEffect(.degrees(-8))
                .offset(y: 22 * s)
        }
    }

    private var sadFace: some View {
        ZStack {
            eyes(curveUp: false)
            Arc(start: .degrees(200), end: .degrees(340), clockwise: false)
                .stroke(Theme.ink, style: .init(lineWidth: 5 * s, lineCap: .round))
                .frame(width: 44 * s, height: 36 * s)
                .offset(y: 30 * s)
        }
    }

    private var awfulFace: some View {
        ZStack {
            dotEyes
            Circle()
                .stroke(Theme.ink, lineWidth: 5 * s)
                .frame(width: 22 * s, height: 24 * s)
                .offset(y: 24 * s)
        }
    }

    private var cryFace: some View {
        ZStack {
            eyes(curveUp: true)
            Arc(start: .degrees(200), end: .degrees(340), clockwise: false)
                .stroke(Theme.ink, style: .init(lineWidth: 4.5 * s, lineCap: .round))
                .frame(width: 44 * s, height: 32 * s)
                .offset(y: 30 * s)
            Capsule()
                .fill(Theme.cry)
                .frame(width: 7 * s, height: 14 * s)
                .overlay(Capsule().stroke(Theme.ink, lineWidth: 1.5 * s))
                .offset(x: -22 * s, y: 6 * s)
        }
    }

    // Shared eye styles

    private var dotEyes: some View {
        HStack(spacing: 24 * s) {
            Circle().fill(Theme.ink).frame(width: 6 * s, height: 6 * s)
            Circle().fill(Theme.ink).frame(width: 6 * s, height: 6 * s)
        }
        .offset(y: -6 * s)
    }

    private func eyes(curveUp: Bool) -> some View {
        HStack(spacing: 22 * s) {
            Arc(start: .degrees(curveUp ? 200 : 20), end: .degrees(curveUp ? 340 : 160), clockwise: false)
                .stroke(Theme.ink, style: .init(lineWidth: 5 * s, lineCap: .round))
                .frame(width: 16 * s, height: 12 * s)
            Arc(start: .degrees(curveUp ? 200 : 20), end: .degrees(curveUp ? 340 : 160), clockwise: false)
                .stroke(Theme.ink, style: .init(lineWidth: 5 * s, lineCap: .round))
                .frame(width: 16 * s, height: 12 * s)
        }
        .offset(y: -8 * s)
    }
}

/// Simple arc shape used for eyes/mouths.
private struct Arc: Shape {
    let start: Angle
    let end: Angle
    let clockwise: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: rect.width / 2,
            startAngle: start, endAngle: end, clockwise: clockwise
        )
        return p
    }
}
