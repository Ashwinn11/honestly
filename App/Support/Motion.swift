import SwiftUI

enum Motion {
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.86)
    static let bouncy = Animation.spring(response: 0.42, dampingFraction: 0.68)
    static let gentle = Animation.spring(response: 0.55, dampingFraction: 0.9)
    static let pop    = Animation.spring(response: 0.35, dampingFraction: 0.6)
}

// MARK: - Shimmer (one soft highlight sweep, then done) — prototype's `shimmerLine`

private struct ShimmerPhase: ViewModifier, Animatable {
    var progress: CGFloat
    var strength: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        content.visualEffect { view, proxy in
            view.colorEffect(ShaderLibrary.shimmer(
                .float2(proxy.size), .float(progress), .float(strength)))
        }
    }
}

private struct ShimmerOnce: ViewModifier {
    var delay: Double
    var strength: CGFloat
    @State private var progress: CGFloat = -0.4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .modifier(ShimmerPhase(progress: progress, strength: strength))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).delay(delay)) { progress = 1.4 }
            }
    }
}

extension View {
    func shimmerOnce(delay: Double = 0.6, strength: CGFloat = 0.35) -> some View {
        modifier(ShimmerOnce(delay: delay, strength: strength))
    }
}

// MARK: - Foil sweep (iridescent sunrise sheen — shows on white, unlike shimmer)

private struct FoilPhase: ViewModifier, Animatable {
    var progress: CGFloat
    var strength: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        content.visualEffect { view, proxy in
            view.colorEffect(ShaderLibrary.foilSweep(
                .float2(proxy.size), .float(progress), .float(strength)))
        }
    }
}

private struct FoilOnce: ViewModifier {
    var delay: Double
    var strength: CGFloat
    @State private var progress: CGFloat = -0.4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .modifier(FoilPhase(progress: progress, strength: strength))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.3).delay(delay)) { progress = 1.4 }
            }
    }
}

extension View {
    func foilSweepOnce(delay: Double = 0.4, strength: CGFloat = 0.3) -> some View {
        modifier(FoilOnce(delay: delay, strength: strength))
    }
}

// MARK: - Ripple on tap (liquid pulse from the touch point)

private struct RippleShader: ViewModifier {
    var origin: CGPoint
    var elapsed: TimeInterval
    var duration: TimeInterval
    func body(content: Content) -> some View {
        content.layerEffect(
            ShaderLibrary.ripple(
                .float2(origin), .float(elapsed),
                .float(10), .float(14), .float(7), .float(1400)),
            maxSampleOffset: CGSize(width: 10, height: 10),
            isEnabled: elapsed > 0 && elapsed < duration)
    }
}

private struct RippleOnTap: ViewModifier {
    var origin: CGPoint
    var trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        let rm = reduceMotion
        return content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, elapsed in
            view.modifier(RippleShader(origin: origin, elapsed: rm ? 0 : elapsed, duration: 0.6))
        } keyframes: { _ in
            MoveKeyframe(0)
            LinearKeyframe(0.6, duration: 0.6)
        }
    }
}

extension View {
    func rippleOnTap(at origin: CGPoint, trigger: Int) -> some View {
        modifier(RippleOnTap(origin: origin, trigger: trigger))
    }
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
