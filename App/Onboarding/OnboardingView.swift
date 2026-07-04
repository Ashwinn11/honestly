import SwiftUI
import FamilyControls

/// The ten-slide onboarding, matching `Honestly.dc.html` 1:1 — a horizontal pager with a Skip
/// affordance, animated illustrations, pager dots, and per-slide CTAs. The Screen Time and
/// notification permission requests are wired into the relevant slides (the OS UI appears over
/// the matching slide, so the visual flow is unchanged).
struct OnboardingView: View {
    var onFinish: () -> Void

    @Environment(ScreenTimeManager.self) private var screenTime
    @State private var step = 0
    @State private var showPicker = false
    @State private var dragX: CGFloat = 0

    private var slides: [OnbSlide] { AppContent.onboarding }
    private var slide: OnbSlide { slides[step] }
    private var isLast: Bool { step == slides.count - 1 }
    private var showSkip: Bool { step > 0 && !isLast }

    var body: some View {
        @Bindable var st = screenTime
        ZStack {
            PaperBackground()
            VStack(spacing: 0) {
                header
                pager
                controls
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $st.selection)
        .onChange(of: showPicker) { _, presented in
            if !presented { advance() }        // picking done → move on
        }
    }

    // MARK: Header (Skip)
    private var header: some View {
        HStack {
            Spacer()
            if showSkip {
                Button("Skip") { finish() }
                    .font(Fonts.ui(14, .bold))
                    .foregroundStyle(Palette.inkSofter)
                    .padding(6)
                    .transition(.opacity)
            }
        }
        .frame(height: 32)
        .padding(.top, 56)
        .padding(.horizontal, 22)
    }

    // MARK: Pager
    private var pager: some View {
        GeometryReader { geo in
            let w = geo.size.width
            HStack(spacing: 0) {
                ForEach(Array(slides.enumerated()), id: \.element.id) { i, s in
                    OnbSlideView(slide: s, active: i == step)
                        .frame(width: w)
                }
            }
            .frame(width: w, alignment: .leading)
            .offset(x: -CGFloat(step) * w + dragX)
            .animation(Motion.gentle, value: step)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { g in dragX = g.translation.width * 0.7 }
                    .onEnded { g in
                        let threshold = w * 0.22
                        if g.translation.width < -threshold, !isLast { step += 1; Haptics.select() }
                        else if g.translation.width > threshold, step > 0 { step -= 1; Haptics.select() }
                        withAnimation(Motion.gentle) { dragX = 0 }
                    }
            )
        }
        .clipped()
    }

    // MARK: Bottom controls
    private var controls: some View {
        VStack(spacing: 4) {
            PagerDots(count: slides.count, index: step)
                .padding(.bottom, 18)

            if slide.kind == .notif {
                PrimaryButton(title: "Allow notifications") {
                    Task {
                        if await MorningNudge.requestAuthorization() { MorningNudge.schedule() }
                        advance()
                    }
                }
                GhostButton(title: "Maybe later") { advance() }
            } else {
                PrimaryButton(title: ctaLabel) { primaryTapped() }
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 14)
        .padding(.bottom, 30)
    }

    private var ctaLabel: String {
        switch slide.kind {
        case .brand: return "Good morning →"
        case .ready: return "Enter Honestly →"
        default:     return "Continue"
        }
    }

    // MARK: Actions
    private func primaryTapped() {
        if slide.kind == .quiet {
            // Screen Time slide → ask permission. Only open the app picker if they granted it;
            // if they tap "Don't Allow", just move on (never show the picker unauthorized).
            Task {
                await screenTime.requestAuthorization()
                if screenTime.authorized { showPicker = true } else { advance() }
            }
            return
        }
        advance()
    }

    private func advance() {
        if isLast { finish() }
        else { withAnimation(Motion.gentle) { step += 1 } }
    }

    private func finish() {
        screenTime.armSchedule()
        SharedState.onboardingComplete = true
        Haptics.success()
        onFinish()
    }
}

// MARK: - One slide (illustration + optional title/body)

private struct OnbSlideView: View {
    let slide: OnbSlide
    let active: Bool

    var body: some View {
        VStack(spacing: 0) {
            OnbIllustration(kind: slide.kind)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 34)

            if slide.hasText {
                VStack(spacing: 11) {
                    Text(slide.title)
                        .font(Fonts.display(27, .bold))
                        .foregroundStyle(Palette.ink)
                        .lineSpacing(2)
                    Text(slide.body)
                        .font(Fonts.ui(15.5, .semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .lineSpacing(4)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
                .padding(.bottom, 10)
            }
        }
    }
}

// MARK: - Illustrations (one per slide kind)

private struct OnbIllustration: View {
    let kind: OnbKind

    var body: some View {
        switch kind {
        case .brand:  brand
        case .noise:  noise
        case .page:   page
        case .moods:  moods
        case .write:  write
        case .grat:   grat
        case .quiet:  quiet
        case .streak: streak
        case .notif:  notif
        case .ready:  ready
        }
    }

    private var brand: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Color(hex: "FFB13C").opacity(0.18)).frame(width: 154, height: 154)
                SunMark(size: 118).spin(period: 26)
            }
            .floaty(period: 6)
            .padding(.bottom, 22)
            Text("Honestly").font(Fonts.display(52, .heavy)).foregroundStyle(Palette.ink)
            Text("The quiet part of the morning — before the world logs on.")
                .font(Fonts.ui(16, .semibold)).foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center).lineSpacing(3)
                .frame(maxWidth: 280).padding(.top, 14)
        }
    }

    private var noise: some View {
        ZStack {
            // phone
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Palette.ink).frame(width: 118, height: 230)
                .shadow(color: Palette.ink.opacity(0.24), radius: 17, y: 9)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "4A3A2A")).frame(width: 100, height: 210)
            // floating notification bars
            bar(Palette.amber, w: 118).offset(x: -46, y: -78).floaty(period: 3.2)
            bar(Palette.mood(1), w: 120).offset(x: 44, y: -24).floaty(period: 3.8, delay: 0.3)
            bar(Palette.mood(4), w: 110).offset(x: -50, y: 30).floaty(period: 3.4, delay: 0.6)
            bar(Palette.mood(2), w: 104).offset(x: 42, y: 78).floaty(period: 3.6, delay: 0.2)
        }
        .frame(width: 210, height: 250)
    }
    private func bar(_ c: Color, w: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(c).frame(width: w, height: 26)
            .shadow(color: c.opacity(0.4), radius: 8, y: 4)
    }

    private var page: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 15) {
                line(0.72, Palette.ink.opacity(0.10))
                line(0.92, Palette.ink.opacity(0.09))
                line(0.84, Palette.ink.opacity(0.09))
                line(0.60, Palette.ink.opacity(0.09))
                line(0.78, Palette.amber.opacity(0.28))
            }
            .padding(EdgeInsets(top: 26, leading: 22, bottom: 26, trailing: 22))
            .frame(width: 210, height: 250, alignment: .topLeading)
            .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color(hex: "78501E").opacity(0.16), radius: 20, y: 12)
            .rotationEffect(.degrees(-4))
            SunMark(size: 52).offset(x: 6, y: -10).floaty(period: 5)
        }
        .frame(width: 226, height: 260)
    }
    private func line(_ frac: CGFloat, _ c: Color) -> some View {
        GeometryReader { g in
            Capsule().fill(c).frame(width: g.size.width * frac, height: 9)
        }.frame(height: 9)
    }

    private var moods: some View {
        HStack(spacing: 10) {
            faceFloat(0, 46, 3.0, 0)
            faceFloat(1, 54, 3.4, 0.15)
            faceFloat(3, 72, 2.8, 0.3)
            faceFloat(2, 54, 3.6, 0.1)
            faceFloat(4, 46, 3.1, 0.25)
        }
    }
    private func faceFloat(_ m: Int, _ s: CGFloat, _ p: Double, _ d: Double) -> some View {
        MoodFace(mood: m, size: s).floaty(amplitude: 8, period: p, delay: d)
    }

    private var write: some View {
        VStack(alignment: .leading, spacing: 18) {
            AnimatedLine(frac: 0.90, color: Palette.amberLight, delay: 0.1)
            AnimatedLine(frac: 1.0, color: Palette.ink.opacity(0.12), delay: 0.4)
            AnimatedLine(frac: 0.74, color: Palette.ink.opacity(0.12), delay: 0.7)
            AnimatedLine(frac: 0.52, color: Palette.amber, delay: 1.0)
        }
        .padding(EdgeInsets(top: 26, leading: 24, bottom: 26, trailing: 24))
        .frame(width: 220)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color(hex: "78501E").opacity(0.14), radius: 20, y: 12)
    }

    private var grat: some View {
        HStack(spacing: 12) {
            ForEach(Array([42, 52, 64, 52, 42].enumerated()), id: \.offset) { i, s in
                SunMark(size: CGFloat(s)).popIn(delay: Double(i) * 0.12)
            }
        }
    }

    private var quiet: some View {
        HStack(alignment: .center, spacing: 14) {
            SleepingAppTile(brand: .instagram, size: 58).floaty(period: 3.4)
            SleepingAppTile(brand: .snapchat, size: 58).floaty(period: 3.0, delay: 0.2)
            SleepingAppTile(brand: .x, size: 58).floaty(period: 3.6, delay: 0.4)
            SleepingAppTile(brand: .whatsapp, size: 58).floaty(period: 3.2, delay: 0.1)
        }
    }

    private var streak: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 8) {
                sun(26, 0.4); sun(34, 0.55); sun(44, 0.7); sun(56, 0.85)
                SunMark(size: 72, stroke: Palette.amberLight, fill: Palette.amber).floaty(period: 3)
            }
            .padding(.bottom, 20)
            Text("12").font(Fonts.display(60, .heavy)).foregroundStyle(Palette.amber)
            Eyebrow(text: "days and counting", color: Palette.inkSofter, tracking: 1, size: 13).padding(.top, 2)
        }
    }
    private func sun(_ s: CGFloat, _ op: Double) -> some View { SunMark(size: s).opacity(op) }

    private var notif: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Palette.amberLight).frame(width: 38, height: 38)
                .overlay(SunMark(size: 24, stroke: .white, fill: .white))
                .shadow(color: Palette.amber.opacity(0.4), radius: 6, y: 4)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Honestly").font(Fonts.ui(13, .heavy)).foregroundStyle(Palette.ink)
                    Spacer()
                    Text("now").font(Fonts.ui(11, .semibold)).foregroundStyle(Palette.inkSofter)
                }
                Text("Good morning. Your page is waiting — the world can hold on a minute.")
                    .font(Fonts.ui(13, .semibold)).foregroundStyle(Color(hex: "5A4A38")).lineSpacing(2)
            }
        }
        .padding(EdgeInsets(top: 14, leading: 15, bottom: 14, trailing: 15))
        .frame(width: 250)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color(hex: "78501E").opacity(0.16), radius: 17, y: 9)
        .floaty(period: 5)
    }

    private var ready: some View {
        ZStack {
            SunMark(size: 24, stroke: Palette.amber, fill: Palette.amber).offset(x: -70, y: -50).floaty(period: 4)
            SunMark(size: 18, stroke: Palette.amber, fill: Palette.amber).offset(x: 74, y: -14).floaty(period: 5, delay: 0.4)
            SunMark(size: 130, stroke: Palette.amberLight, fill: Palette.amberLight).spin(period: 24).floaty(period: 6)
        }
        .frame(height: 180)
    }
}

/// A ruled line that draws itself in left→right on appear (the prototype's `shimmerLine`).
private struct AnimatedLine: View {
    let frac: CGFloat
    let color: Color
    var delay: Double
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { g in
            Capsule().fill(color)
                .frame(width: g.size.width * frac, height: 11)
                .scaleEffect(x: shown ? 1 : 0, anchor: .leading)
        }
        .frame(height: 11)
        .onAppear {
            if reduceMotion { shown = true; return }
            withAnimation(.easeOut(duration: 1.1).delay(delay)) { shown = true }
        }
    }
}
