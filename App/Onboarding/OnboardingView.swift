import SwiftUI
import WidgetKit

struct OnboardingView: View {
    var onFinish: () -> Void

    @Environment(AffirmationList.self) private var affirmations
    @Environment(PremiumManager.self) private var premium

    @State private var index = 0
    @State private var forward = true
    @State private var picks: [String] = []
    @State private var morningAnswer: MorningAnswer?
    @State private var journalAnswer: JournalAnswer?

    private enum Beat: Int, CaseIterable {
        case brand, morning, journaling, affirmations, personal, social, notif, paywall
    }
    private let beats = Beat.allCases
    private var beat: Beat { beats[index] }

    private var dotTotal: Int { beats.count - 1 }
    private var canGoBack: Bool { index > 0 }

    var body: some View {
        ZStack {
            PaperBackground()
            if beat == .paywall {
                PaywallView(onClose: finish)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                beatView
                    .id(index)
                    .transition(slide)
                    .capWidth(Metrics.maxContentWidth)
            }
        }
        .overlay(alignment: .top) {
            if beat == .brand {          // language picker lives on the very first screen
                LanguagePickerPill().padding(.top, 6)
            }
        }
        .animation(Motion.gentle, value: index)
        .onAppear { picks = affirmations.selectedTopics }
    }

    private var slide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal:   .move(edge: forward ? .leading : .trailing).combined(with: .opacity))
    }

    // MARK: - Per-beat body

    @ViewBuilder private var beatView: some View {
        switch beat {
        case .brand:
            chrome(primary: .init(title: "Start my morning") { advance() }) {
                OnbWelcomeView()
            }

        case .morning:
            chrome(primary: .init(title: "Continue", enabled: morningAnswer != nil) { advance() }) {
                OnbMorningQuestionView(selection: $morningAnswer)
            }

        case .journaling:
            chrome(primary: .init(title: "Continue", enabled: journalAnswer != nil) { advance() }) {
                OnbJournalQuestionView(selection: $journalAnswer)
            }

        case .affirmations:
            chrome(primary: .init(title: "Continue") {
                affirmations.setSelectedTopics(picks)
                advance()
            }) {
                OnbAffirmationQuestionView(picks: $picks, sample: sampleAffirmation)
            }

        case .personal:
            chrome(primary: .init(title: "Continue") { advance() }) {
                OnbPersonalizedPlanView(title: planTitle, affirmation: sampleAffirmation)
            }

        case .social:
            chrome(primary: .init(title: "Continue") { advance() }) {
                OnbSocialProofView()
            }

        case .notif:
            chrome(primary: .init(title: "Allow notifications") { requestNotifications() },
                   secondary: .init(title: "Maybe later") { advance() }) {
                OnbReminderView(affirmation: reminderSamples.first ?? sampleAffirmation)
            }

        case .paywall:
            EmptyView()   // handled at the top level
        }
    }

    // MARK: - Shared chrome (content + footer grouped and centered)

    @ViewBuilder
    private func chrome<C: View>(primary: FooterButton,
                                 secondary: FooterLink? = nil,
                                 @ViewBuilder content: @escaping () -> C) -> some View {
        VStack(spacing: 0) {
            OnbDots(index: index, total: dotTotal)
                .padding(.top, beat == .brand ? 42 : 8)
                .padding(.bottom, 8)
            GeometryReader { geo in
                ScrollView {
                    content()
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geo.size.height, alignment: .center)
                        .padding(.horizontal, 26)   // padding lives here so shadows bleed freely
                        .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
            footer(primary: primary, secondary: secondary)   // pinned at the bottom
                .padding(.horizontal, 26)
        }
        .padding(.top, 8)
        .padding(.bottom, 30)
    }

    private func footer(primary: FooterButton, secondary: FooterLink?) -> some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                if canGoBack { backButton }
                ctaButton(primary)
            }
            if let secondary {
                HStack(spacing: 12) {
                    // Mirror the back button's gutter so the link centers under the CTA, not the footer.
                    if canGoBack { Color.clear.frame(width: DesignScale.s(56), height: 1) }
                    Button { Haptics.tap(); secondary.action() } label: {
                        Text(loc: secondary.title)
                            .font(Fonts.ui(14.5, .bold)).foregroundStyle(Palette.inkSofter)
                            .frame(maxWidth: .infinity).padding(.vertical, 2)
                    }
                    .buttonStyle(PressableStyle(scale: 0.98))
                }
            }
        }
    }

    private var backButton: some View {
        IconTileButton(icon: "chevron.backward", size: 56, iconSize: 16,
                       iconColor: Palette.ink, fill: Palette.cream, radius: 17) { back() }
    }

    private func ctaButton(_ b: FooterButton) -> some View {
        Button {
            guard b.enabled else { return }
            Haptics.tap(); b.action()
        } label: {
            Text(loc: b.title)
                .font(Fonts.ui(16.5, .heavy))
                .foregroundStyle(b.enabled ? .white : Palette.inkSofter)
                .frame(maxWidth: .infinity, minHeight: DesignScale.s(56))
                .background(b.enabled ? AnyShapeStyle(Palette.amber) : AnyShapeStyle(Palette.ink.opacity(0.06)),
                            in: RoundedRectangle(cornerRadius: DesignScale.s(Radius.panel), style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DesignScale.s(Radius.panel), style: .continuous)
                    .strokeBorder(Palette.ink, lineWidth: b.enabled ? 2 : 0))
                .tactile(b.enabled ? 4 : 0, cornerRadius: DesignScale.s(Radius.panel))
        }
        .buttonStyle(PressableStyle())
        .disabled(!b.enabled)
        .animation(Motion.snappy, value: b.enabled)
    }

    private struct FooterButton {
        let title: String
        var enabled: Bool = true
        let action: () -> Void
    }
    private struct FooterLink {
        let title: String
        let action: () -> Void
    }

    private var sampleAffirmation: String {
        if sampleAffirmationTopic == "Your own", premium.allows(.ownAffirmations) {
            return affirmations.savedCustom.first ?? "You deserve care and kindness."
        }
        let topic = sampleAffirmationTopic
        return affirmations.availableLibrary.first(where: { $0.title == topic })?.lines.first
            ?? affirmations.availableLibrary.first?.lines.first
            ?? "You deserve care and kindness."
    }

    private var sampleAffirmationTopic: String {
        picks.last ?? affirmations.availableLibrary.first?.title ?? ""
    }

    private var reminderSamples: [String] {
        let topic = sampleAffirmationTopic
        let lines: [String]
        if topic == "Your own", premium.allows(.ownAffirmations) {
            lines = affirmations.savedCustom
        } else {
            lines = affirmations.availableLibrary.first(where: { $0.title == topic })?.lines
                ?? affirmations.availableLibrary.first?.lines
                ?? []
        }
        return Array(lines.prefix(2)).isEmpty ? [sampleAffirmation] : Array(lines.prefix(2))
    }

    // The morning answer (where app blocking speaks) titles the plan.
    private var planTitle: String {
        morningAnswer?.summaryTitle ?? "A morning with more room for you."
    }

    // MARK: - Navigation

    private func advance() {
        guard index < beats.count - 1 else { return }
        forward = true
        withAnimation(Motion.gentle) { index += 1 }
    }

    private func back() {
        guard index > 0 else { return }
        forward = false
        withAnimation(Motion.gentle) { index = max(0, index - 1) }
    }

    private func requestNotifications() {
        Task {
            // Allowing notifications here turns the reminders on — the screen just promised them.
            if await AffirmationNudge.requestPermission() { AffirmationNudge.enable() }
            advance()
        }
    }

    private func finish() {
        SharedState.onboardingComplete = true
        // The widget says "Open Honestly to get started" until now; flush so it sees the change.
        SharedState.defaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
        Haptics.success()
        onFinish()
    }
}

// MARK: - Dotted progress

private struct OnbDots: View {
    let index: Int      // current beat (0-based)
    let total: Int
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i <= index ? Palette.amber : Palette.ink.opacity(0.12))
                    .frame(width: i == index ? 8 : 6, height: i == index ? 8 : 6)
            }
        }
        .animation(Motion.snappy, value: index)
    }
}

// MARK: - The opening promise and personalizer
private struct OnbHeader: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(spacing: 10) {
            Eyebrow(text: eyebrow, tracking: 1.6, size: 12)
            Text(loc: title)
                .font(Fonts.display(24, .bold))
                .foregroundStyle(Palette.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }
}

private enum MorningAnswer: String, CaseIterable, Identifiable {
    case phone, racingMind, rushing, routine
    var id: String { rawValue }
    var title: String {
        switch self {
        case .phone: "I reach for my phone first"
        case .racingMind: "My mind is already racing"
        case .rushing: "I rush into everyone else’s needs"
        case .routine: "It’s hard to keep a morning routine"
        }
    }
    var summaryTitle: String {
        switch self {
        case .phone: "Give yourself a moment before the feed."
        case .racingMind: "Give your thoughts a little room."
        case .rushing: "Make space for what you need, too."
        case .routine: "A small ritual can be easier to return to."
        }
    }
}

private enum JournalAnswer: String, CaseIterable, Identifiable {
    case blankPage, time, tangled, consistency
    var id: String { rawValue }
    var title: String {
        switch self {
        case .blankPage: "I don’t know where to start"
        case .time: "I struggle to make time"
        case .tangled: "My thoughts feel tangled"
        case .consistency: "I forget to come back to it"
        }
    }
    var summaryTitle: String {
        switch self {
        case .blankPage: "You don’t need the perfect words."
        case .time: "A few honest lines can make room for you."
        case .tangled: "Give your thoughts somewhere to land."
        case .consistency: "A small ritual can be easier to return to."
        }
    }
}

private struct OnbWelcomeView: View {
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                SoftGlow(color: Palette.sunDisc, opacity: 0.22, size: 280)
                SunMark(size: 118).spin(period: 26)
                InkGlyph(kind: .sparkle, size: 24, fill: Palette.glyphGold)
                    .offset(x: -74, y: -60)
                    .floaty(period: 4)
                InkGlyph(kind: .heart, size: 20, fill: Palette.glyphBlush)
                    .offset(x: 76, y: -44)
                    .floaty(period: 5, delay: 0.4)
            }
            .floaty(period: 6)
            .padding(.bottom, 22)
            Text("Honestly")
                .font(Fonts.display(52, .heavy))
                .foregroundStyle(Palette.ink)
            Text(loc: "Let it out on the page. Find words that lift you.")
                .font(Fonts.ui(16, .semibold))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 280)
                .padding(.top, 18)
        }
    }
}

private struct OnbMorningQuestionView: View {
    @Binding var selection: MorningAnswer?

    var body: some View {
        VStack(spacing: 16) {
            OnbHeader(eyebrow: "Your mornings", title: "What gets in the way of a morning that feels like yours?")
            VStack(spacing: 9) {
                ForEach(MorningAnswer.allCases) { answer in
                    OnbChoiceRow(title: answer.title, selected: selection == answer) {
                        Haptics.select()
                        selection = answer
                    }
                }
            }
            AppBlockLoop()
        }
    }
}

private struct OnbJournalQuestionView: View {
    @Binding var selection: JournalAnswer?

    var body: some View {
        VStack(spacing: 10) {
            OnbHeader(eyebrow: "Your journaling", title: "What makes journaling hard to return to?")
            VStack(spacing: 9) {
                ForEach(JournalAnswer.allCases) { answer in
                    OnbChoiceRow(title: answer.title, selected: selection == answer) {
                        Haptics.select()
                        selection = answer
                    }
                }
            }
            JournalWritingIllustration()
                .padding(.top, 6)
        }
    }
}

private struct OnbAffirmationQuestionView: View {
    @Binding var picks: [String]
    let sample: String

    var body: some View {
        VStack(spacing: 0) {
            OnbHeader(eyebrow: "Your affirmations", title: "What would you like affirmations to support?")
                .padding(.bottom, 18)
            AffirmationTopicPicker(selection: $picks, onSelection: { Haptics.select() }, collapsedCount: 6)
                .padding(.bottom, 5)
            OnbAffirmationPreview(text: sample, topic: picks.last ?? "")
        }
    }
}

private struct OnbPersonalizedPlanView: View {
    let title: String
    let affirmation: String

    var body: some View {
        VStack(spacing: 26) {
            OnbHeader(eyebrow: "Made for your mornings", title: title)
            MorningOutcomeCard(affirmation: affirmation)
                .rotationEffect(.degrees(-4))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .background(alignment: .center) {
            SoftGlow(color: Palette.sunDisc, opacity: 0.14, size: 300)
        }
    }
}

// MARK: - Tomorrow morning, played once (locked → write → apps unlock → affirmation)

/// Shows the outcome rather than the steps: the apps from the morning question sit locked while the
/// pencil writes a page, the meter fills with the ink, and the apps wake up the moment the page is
/// done — then the user's own affirmation arrives. It ends, and stays, there; Reduce Motion lands
/// on that end state straight away.
private struct MorningOutcomeCard: View {
    let affirmation: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = Phase.locked
    @State private var ink: CGFloat = 0              // how much of the page is written
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
                    Image(systemName: "quote.opening")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.amberDeep)
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
        BookWritingScene(mood: 1, lines: Self.pageLines, pageWidth: 92, onInk: { value in
            ink = value
            if value > 0 && phase == .locked { phase = .writing }
        }, onWritten: { Task { await unlock() } })
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

private struct OnbChoiceRow: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(loc: title)
                    .font(Fonts.ui(14, .semibold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(selected ? Palette.ink : Palette.outlineSoft)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(selected ? Palette.amber : Palette.cream,
                        in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .strokeBorder(selected ? Palette.ink : Palette.outlineSoft, lineWidth: selected ? 1.8 : 1.2))
            .contentShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        }
        .buttonStyle(PressableStyle(scale: 0.98))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The month's book opening and a page being written in it, again and again — the book the
/// user will write in, met before they ever open it.
private struct JournalWritingIllustration: View {
    private static let lines = [
        "There’s a lot on my mind",
        "this morning, so I’ll start",
        "with just one thing."
    ]

    var body: some View {
        VStack(spacing: 12) {
            BookWritingScene(lines: Self.lines, pageWidth: 124, loops: true)
                .rotationEffect(.degrees(-3))
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Palette.amberDeep)
                Text(loc: "A few honest lines are enough.")
                    .foregroundStyle(Palette.inkSoft)
            }
            .font(Fonts.ui(11, .semibold))
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .background { SoftGlow(color: Palette.sunDisc, opacity: 0.22, size: 320) }
        .accessibilityHidden(true)
    }
}

private struct OnbAffirmationPreview: View {
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
            PageThemeBackground(theme: widgetTheme)

            VStack(spacing: 5) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .accessibilityHidden(true)
                Affirmations.text(text)
                    .font(Font(widgetFont.uiFont(size: DesignScale.s(16))).weight(.semibold))
                    .foregroundStyle(Palette.ink)
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

private struct AppBlockLoop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lockedCount = 0
    private let brands: [Brand] = [.instagram, .tiktok, .snapchat]

    var body: some View {
        VStack(spacing: 8) {
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
            Text(loc: "Write first, scroll later.")
                .font(Fonts.ui(11.5, .bold))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityHidden(true)
        .task { await animateLocks() }
    }

    private func animateLocks() async {
        guard !reduceMotion else { lockedCount = brands.count; return }
        while !Task.isCancelled {
            lockedCount = 0
            do {
                try await Task.sleep(for: .milliseconds(450))
                for count in 1...brands.count {
                    withAnimation(Motion.pop) { lockedCount = count }
                    try await Task.sleep(for: .milliseconds(330))
                }
                try await Task.sleep(for: .seconds(1.2))
            } catch {
                return
            }
        }
    }
}

// MARK: - Notification preview

/// A notification as it will arrive: its title, what it says, and when.
private struct NotifCard<Message: View>: View {
    let title: String                    // String Catalog key
    let time: String
    @ViewBuilder var message: Message

    var body: some View {
        HStack(alignment: .top, spacing: DesignScale.s(12)) {
            Image("app-mark").resizable().scaledToFill()
                .frame(width: DesignScale.s(42), height: DesignScale.s(42))
                .clipShape(RoundedRectangle(cornerRadius: DesignScale.s(Radius.tile), style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DesignScale.s(Radius.tile), style: .continuous).strokeBorder(Palette.ink.opacity(0.12), lineWidth: 1))
            VStack(alignment: .leading, spacing: DesignScale.s(3)) {
                HStack(alignment: .firstTextBaseline) {
                    Text(loc: title).font(Fonts.ui(14, .heavy)).foregroundStyle(Palette.ink)
                    Spacer()
                    Text(verbatim: time).font(Fonts.ui(12, .semibold)).foregroundStyle(Palette.inkSofter)
                }
                message
                    .font(Fonts.ui(13.5, .semibold)).foregroundStyle(Palette.notifBody)
                    .lineSpacing(2).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(EdgeInsets(top: DesignScale.s(15), leading: DesignScale.s(15), bottom: DesignScale.s(15), trailing: DesignScale.s(16)))
        .frame(maxWidth: DesignScale.s(330))
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignScale.s(Radius.card), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DesignScale.s(Radius.card), style: .continuous).strokeBorder(Palette.ink, lineWidth: 2))
        .shadow(color: Palette.warmShadow.opacity(0.14), radius: DesignScale.s(16), y: DesignScale.s(9))
        .accessibilityElement(children: .combine)
    }
}

/// The two notifications Honestly sends, as they'll arrive: the writing page's prompt in the
/// evening when the day's page is still blank, and an affirmation at the times the user picks.
private struct OnbReminderView: View {
    let affirmation: String
    @Environment(PromptLibrary.self) private var prompts
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visibleCount = 0

    var body: some View {
        VStack(spacing: 24) {
            OnbHeader(eyebrow: "Two gentle reminders", title: "Today's prompt, and a kind thought.")
            VStack(spacing: 12) {
                if visibleCount > 0 {
                    NotifCard(title: "Journal reminder", time: clock(AffirmationNudge.reminderHour * 60)) {
                        Text(verbatim: prompts.pageText ?? L10n.localized("Write today's page — a few quiet minutes, just for you."))
                    }
                    .transition(arrival)
                }
                if visibleCount > 1 {
                    NotifCard(title: "Today's affirmation", time: clock(AffirmationNudge.defaultMinutes)) {
                        Affirmations.text(affirmation)
                    }
                    .transition(arrival)
                }
            }
        }
        .task { await revealNotifications() }
    }

    private var arrival: AnyTransition {
        .asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity)
    }

    /// A time of day in the app's language — 8:00 PM, 20:00.
    private func clock(_ minutes: Int) -> String {
        let time = Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        return time.formatted(.dateTime.hour().minute().locale(HDate.appLocale))
    }

    private func revealNotifications() async {
        guard !reduceMotion else {
            visibleCount = 2
            Haptics.notificationSound()
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(300))
            for index in 0..<2 {
                withAnimation(Motion.snappy) { visibleCount = index + 1 }
                Haptics.notificationSound()
                if index == 0 { try await Task.sleep(for: .milliseconds(700)) }
            }
        } catch {
            return
        }
    }
}

// MARK: - Social proof

private struct OnbSocialProofView: View {
    private var sp: SocialProof { AppContent.socialProof }
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        VStack(spacing: 16) {
            OnbHeader(eyebrow: "From the App Store", title: "A small part of\nsomeone’s morning.")
            HStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { index in
                    InkGlyph(kind: .star, size: 28, fill: Palette.glyphGold, lineWidth: 1.4)
                        .opacity(hasAppeared ? 1 : 0)
                        .scaleEffect(hasAppeared ? 1 : 0.9)
                        .animation(reduceMotion ? nil : Motion.snappy.delay(Double(index) * 0.07),
                                   value: hasAppeared)
                }
            }
            if sp.hasStats {
                Text(sp.rating).font(Fonts.display(40, .heavy)).foregroundStyle(Palette.ink)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared || reduceMotion ? 0 : 7)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.22).delay(0.28),
                               value: hasAppeared)
            }

            VStack(spacing: 12) {
                ForEach(sp.quotes) { q in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("“\(Text(loc: q.text))”")
                            .font(Fonts.ui(15, .bold)).foregroundStyle(Palette.ink).lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("— \(q.author)")
                            .font(Fonts.ui(12.5, .semibold)).foregroundStyle(Palette.inkSofter)
                        if locale.language.languageCode?.identifier != "en" {
                            Text(loc: "Translated from English")
                                .font(Fonts.ui(11, .medium)).foregroundStyle(Palette.inkSofter)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .softCard(padding: 16)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared || reduceMotion ? 0 : 8)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.22).delay(0.42 + Double(sp.quotes.firstIndex(where: { $0.id == q.id }) ?? 0) * 0.12),
                               value: hasAppeared)
                }
            }
        }
        // Glow anchored near the top (behind the stars/heading), so it stays put as the cards grow.
        .background(alignment: .top) { SoftGlow(color: Palette.sunDisc, opacity: 0.16, size: 300).offset(y: 40) }
        .task {
            if reduceMotion {
                hasAppeared = true
            } else {
                try? await Task.sleep(for: .milliseconds(120))
                withAnimation(Motion.snappy) { hasAppeared = true }
            }
        }
    }

}
