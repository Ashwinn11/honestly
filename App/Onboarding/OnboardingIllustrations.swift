import SwiftUI

// The moving pictures onboarding uses: the morning played out (once, on the plan), the
// affirmation preview, and the apps falling asleep (after a purchase, choosing them).

// MARK: - Tomorrow morning, played once (locked → write → apps unlock → affirmation)

/// Shows the outcome rather than the steps: the feed apps sit locked while the
/// pencil writes a page, the meter fills with the ink, and the apps wake up the moment the page is
/// done — then the user's own affirmation arrives. It ends, and stays, there; Reduce Motion lands
/// on that end state straight away.
struct MorningOutcomeCard: View {
    let affirmation: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = Phase.locked
    @State private var ink: CGFloat = 0              // how much of the page is written
    @State private var didUnlock = false
    private let brands: [Brand] = [.instagram, .tiktok, .snapchat]

    private static let pageLines = [
        "Woke up a little anxious,",
        "but writing it out helps.",
        "Today, I’ll go slow."
    ]

    private enum Phase: Int {
        case locked, writing, unlocked, affirming
    }

    private var unlocked: Bool { phase.rawValue >= Phase.unlocked.rawValue }


    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text(verbatim: clock)
                    .font(Fonts.ui(12.5, .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkSoft)
                    .contentTransition(.numericText())
                    .animation(Motion.snappy, value: clock)
                Spacer(minLength: 8)
                SunMark(size: 24)
                    .scaleEffect(unlocked ? 1.15 : 1)
            }
            VStack(spacing: 14) {
                apps
                meter
            }
            stage
        }
        .padding(18)
        .frame(maxWidth: 300)
        .background(Palette.cream, in: RoundedRectangle(cornerRadius: Radius.hero, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.hero, style: .continuous)
            .stroke(Palette.ink, lineWidth: 2))
        .tactile(5, cornerRadius: Radius.hero)
        .shadow(color: Palette.ink.opacity(0.09), radius: 18, x: 0, y: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(loc: "Block apps until you write"))
    }

    /// 7:00, ticking while the page is written, 7:04 at the unlock, in the app's language.
    private var clock: String {
        let minute = switch phase {
        case .locked:    0
        case .writing:   1 + min(2, Int(ink * 3))
        case .unlocked:  4
        case .affirming: 5
        }
        let time = Calendar.current.date(bySettingHour: 7, minute: minute, second: 0, of: .now) ?? .now
        return time.formatted(.dateTime.hour().minute().locale(HDate.appLocale))
    }

    private var apps: some View {
        HStack(spacing: 18) {
            ForEach(Array(brands.enumerated()), id: \.offset) { index, brand in
                BrandIcon(brand: brand, size: 50)
                    .grayscale(unlocked ? 0 : 1)
                    .opacity(unlocked ? 1 : 0.45)
                    .scaleEffect(unlocked ? 1 : 0.9)
                    .overlay(alignment: .topTrailing) {
                        if !unlocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Palette.ink, in: Circle())
                                .overlay(Circle().strokeBorder(Palette.cream, lineWidth: 1.5))
                                .offset(x: 5, y: -5)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(Motion.pop.delay(Double(index) * 0.09), value: unlocked)
            }
        }
        .background {
            SoftGlow(color: Palette.sunDisc, opacity: unlocked ? 0.4 : 0, size: 240)
                .animation(.easeOut(duration: 0.8), value: unlocked)
        }
    }

    /// Fills with the ink as the page is written; full means unlocked.
    private var meter: some View {
        let fill = unlocked ? 1 : max(0.04, ink)
        return Capsule()
            .fill(Palette.ink.opacity(0.08))
            .frame(maxWidth: 190)
            .frame(height: 5)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(Palette.amber)
                        .frame(width: geo.size.width * fill)
                }
            }
            .animation(.linear(duration: 0.12), value: fill)
    }

    @ViewBuilder private var stage: some View {
        ZStack {
            if phase != .affirming {
                page.transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                VStack(spacing: 6) {
                    QuoteMark(size: 16)
                    Affirmations.text(affirmation)
                        .font(Font(FontChoice.baskerville.uiFont(size: DesignScale.s(17))))
                        .foregroundStyle(Palette.ink)
                        .lineSpacing(2)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.75)
                }
                .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        // Fixed, so the card never resizes as the page gives way to the affirmation.
        .frame(maxWidth: .infinity)
        .frame(height: DesignScale.s(140))
    }

    /// The month's book opening and the page being written — the same book as the journaling
    /// screen, played once.
    private var page: some View {
        BookWritingScene(mood: 1, lines: Self.pageLines, pageWidth: 92, loops: true, onInk: { value in
            ink = value
            if value > 0 && phase == .locked { phase = .writing }
        }, onWritten: {
            guard !didUnlock else { return }
            didUnlock = true
            Task { await unlock() }
        })
    }

    private func unlock() async {
        guard !reduceMotion else {
            phase = .affirming
            return
        }
        // The page is written, so the apps wake up.
        withAnimation(Motion.gentle) { phase = .unlocked }
        Haptics.success()
        try? await Task.sleep(for: .milliseconds(1100))
        withAnimation(Motion.gentle) { phase = .affirming }
    }
}


struct OnbAffirmationPreview: View {
    let text: String
    let topic: String

    private var topicIndex: Int {
        Affirmations.library.firstIndex(where: { $0.title == topic }) ?? 0
    }
    // Onboarding skips the plain basics (Classic, Grid, Dotted) and the app's UI font, and opens
    // on Ink & Gold in Didot for "All topics" and the first topic.
    private static let themes: [PageTheme] =
        [.inkGold] + PageTheme.allCases.filter { ![.paper, .grid, .dots, .inkGold].contains($0) }
    private static let fonts: [FontChoice] =
        [.didot] + FontChoice.allCases.filter { ![.manrope, .didot].contains($0) }

    private var widgetTheme: PageTheme {
        Self.themes[topicIndex % Self.themes.count]
    }
    private var widgetFont: FontChoice {
        Self.fonts[topicIndex % Self.fonts.count]
    }

    var body: some View {
        ZStack {
            PageThemeBackground(theme: widgetTheme, layout: .widget)

            VStack(spacing: 5) {
                QuoteMark(size: 15)
                Affirmations.text(text)
                    .font(Font(widgetFont.uiFont(size: DesignScale.s(16))).weight(.semibold))
                    .foregroundStyle(widgetTheme.ink)
                    .lineSpacing(1)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: 250, maxHeight: .infinity)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: 300)
        .frame(height: 118)
        .clipShape(RoundedRectangle(cornerRadius: Radius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.hero, style: .continuous)
                .strokeBorder(Palette.ink.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: Palette.ink.opacity(0.10), radius: 13, x: 0, y: 6)
        .accessibilityElement(children: .combine)
    }
}

struct AppBlockLoop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingAnimationsActive) private var animationsActive
    @State private var lockedCount = 0
    private let brands: [Brand] = [.instagram, .tiktok, .snapchat]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(brands.enumerated()), id: \.offset) { index, brand in
                ZStack(alignment: .topTrailing) {
                    BrandIcon(brand: brand, size: 42)
                        .grayscale(index < lockedCount ? 1 : 0)
                        .opacity(index < lockedCount ? 0.48 : 1)
                    if index < lockedCount {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(Palette.ink, in: Circle())
                            .overlay(Circle().strokeBorder(Palette.paper, lineWidth: 1.5))
                            .offset(x: 4, y: -4)
                    }
                }
                .animation(Motion.pop, value: lockedCount)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Palette.cream.opacity(0.88), in: RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
            .strokeBorder(Palette.outlineSoft, lineWidth: 1.2))
        .accessibilityHidden(true)
        .task(id: animationsActive) {
            lockedCount = 0
            guard animationsActive else { return }
            await animateLocks()
        }
    }

    private func animateLocks() async {
        guard !reduceMotion else { lockedCount = brands.count; return }
        while !Task.isCancelled {
            lockedCount = 0
            do {
                try await Task.sleep(for: .milliseconds(200))
                for count in 1...brands.count {
                    withAnimation(Motion.pop) { lockedCount = count }
                    try await Task.sleep(for: .milliseconds(240))
                }
                try await Task.sleep(for: .seconds(1.2))
            } catch {
                return
            }
        }
    }
}
