import SwiftUI

// ART: Placeholder potted-plant character that grows by stage.
// Replace internals with supplied illustrations; keep PlantView(stage:size:) API.

struct PlantView: View {
    var stage: PlantStage = .sprout
    var size: CGFloat = 80
    var showFace: Bool = true

    private var s: CGFloat { size / 80 }

    var body: some View {
        ZStack {
            // Foliage by stage
            foliage
            // Pot
            pot
            if showFace { potFace }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder private var foliage: some View {
        switch stage {
        case .sprout:    leaves(count: 2, spread: 14 * s, height: 22 * s)
        case .young:     leaves(count: 4, spread: 18 * s, height: 26 * s)
        case .mature:    leaves(count: 6, spread: 22 * s, height: 30 * s)
        case .flowering: ZStack { leaves(count: 6, spread: 22 * s, height: 30 * s); blossoms }
        }
    }

    private func leaves(count: Int, spread: CGFloat, height: CGFloat) -> some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let t = count == 1 ? 0 : CGFloat(i) / CGFloat(count - 1)
                let angle = -spread + t * (spread * 2)
                Capsule()
                    .fill(Theme.confused)
                    .overlay(Capsule().stroke(Theme.ink, lineWidth: 2 * s))
                    .frame(width: 12 * s, height: height)
                    .rotationEffect(.degrees(Double(angle) * 2))
                    .offset(y: -height / 2 - 6 * s)
            }
        }
        .offset(y: -8 * s)
    }

    private var blossoms: some View {
        HStack(spacing: 6 * s) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(Theme.sad)
                    .overlay(Circle().stroke(Theme.ink, lineWidth: 1.6 * s))
                    .frame(width: 12 * s, height: 12 * s)
            }
        }
        .offset(y: -34 * s)
    }

    private var pot: some View {
        Trapezoid()
            .fill(Theme.orange)
            .overlay(Trapezoid().stroke(Theme.ink, lineWidth: 2.2 * s))
            .frame(width: 38 * s, height: 26 * s)
            .offset(y: 22 * s)
    }

    private var potFace: some View {
        HStack(spacing: 8 * s) {
            Circle().fill(Theme.ink).frame(width: 3 * s, height: 3 * s)
            Circle().fill(Theme.ink).frame(width: 3 * s, height: 3 * s)
        }
        .offset(y: 20 * s)
    }
}

/// Flowerpot trapezoid (wider at top).
private struct Trapezoid: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let inset = rect.width * 0.12
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
