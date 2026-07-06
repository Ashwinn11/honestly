import SwiftUI

enum Motion {
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.86)
    static let bouncy = Animation.spring(response: 0.42, dampingFraction: 0.68)
    static let gentle = Animation.spring(response: 0.55, dampingFraction: 0.9)
    static let pop    = Animation.spring(response: 0.35, dampingFraction: 0.6)
    static let press  = Animation.spring(response: 0.20, dampingFraction: 0.72)   // key-press physics
}

// MARK: - Staggered entrance (rows / cards cascading in) — prototype's `riseIn`

private struct StaggeredAppear: ViewModifier {
    let index: Int
    var baseDelay: Double = 0
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .blur(radius: shown ? 0 : 3)
            .onAppear {
                guard !shown else { return }
                if reduceMotion { shown = true; return }
                withAnimation(Motion.gentle.delay(baseDelay + Double(index) * 0.05)) { shown = true }
            }
    }
}

extension View {
    func staggeredAppear(index: Int, baseDelay: Double = 0) -> some View {
        modifier(StaggeredAppear(index: index, baseDelay: baseDelay))
    }
}

// MARK: - Pop-in (faces / pills / floating accents arriving with a spring)

private struct PopIn: ViewModifier {
    var delay: Double
    var from: CGFloat
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown ? 1 : from)
            .opacity(shown ? 1 : 0)
            .onAppear {
                guard !shown else { return }
                if reduceMotion { shown = true; return }
                withAnimation(Motion.pop.delay(delay)) { shown = true }
            }
    }
}

extension View {
    func popIn(delay: Double = 0, from: CGFloat = 0.5) -> some View {
        modifier(PopIn(delay: delay, from: from))
    }

    func floaty(amplitude: CGFloat = 9, period: Double = 6, delay: Double = 0) -> some View {
        modifier(Floaty(amplitude: amplitude, period: period, delay: delay))
    }
}

// MARK: - Spin (continuous slow rotation) — prototype's `sunSpin`

private struct Spin: ViewModifier {
    var period: Double
    @State private var angle: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: period).repeatForever(autoreverses: false)) { angle = 360 }
            }
    }
}

extension View {
    func spin(period: Double = 24) -> some View { modifier(Spin(period: period)) }
}

// MARK: - Floaty (ambient bob) — prototype's `floaty` / `floatySlow`

private struct Floaty: ViewModifier {
    var amplitude: CGFloat
    var period: Double
    var delay: Double
    @State private var up = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(y: up ? -amplitude : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: period / 2).repeatForever(autoreverses: true).delay(delay)) {
                    up = true
                }
            }
    }
}
