import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void

    @Environment(JournalStore.self) private var store

    @State private var answers = OnboardingAnswers()
    @State private var index = 0
    @State private var forward = true

    private enum Beat: Int, CaseIterable {
        case brand, problem, goal, scroll, pain, apps, commitment, building, plan, ritual, social, notif, paywall
    }
    private let beats = Beat.allCases
    private var beat: Beat { beats[index] }

    private var dotTotal: Int { beats.count - 1 }
    private var canGoBack: Bool { index > 0 && beat != .building }

    /// What the notification-permission preview shows: their own demo affirmation, or the default
    /// until they've written one — matches exactly what `AffirmationNudge` will actually send.
    private var previewAffirmation: String {
        let mine = answers.demoAffirmation.trimmingCharacters(in: .whitespacesAndNewlines)
        return mine.isEmpty ? AppContent.defaultAffirmation : mine
    }

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
            chrome(primary: .init(title: "Good morning") { advance() }) {
                narrative(.brand)
            }

        case .problem:
            chrome(primary: .init(title: "Continue") { advance() }) {
                narrative(.noise, title: AppContent.onbProblemTitle, body: AppContent.onbProblemBody)
            }

        case .goal:
            chrome(primary: .init(title: "Continue", enabled: !answers.goals.isEmpty) { advance() }) {
                questionColumn(AppContent.goalQuestion, hint: AppContent.goalHint) {
                    ForEach(OnbGoal.allCases) { g in
                        OnbOptionRow(label: g.option, selected: answers.isGoalSelected(g), multi: true) {
                            withAnimation(Motion.snappy) { answers.toggleGoal(g) }
                            Haptics.select()
                        }
                    }
                }
            }

        case .scroll:
            chrome(primary: .init(title: "Continue", enabled: answers.scrollMinutes > 0) { advance() }) {
                questionColumn(AppContent.scrollQuestion) {
                    ForEach(AppContent.scrollOptions) { opt in
                        OnbOptionRow(label: opt.label, note: opt.note,
                                     selected: answers.scrollMinutes == opt.minutes) {
                            withAnimation(Motion.snappy) { answers.scrollMinutes = opt.minutes }
                            Haptics.select()
                        }
                    }
                }
            }

        case .pain:
            chrome(primary: .init(title: "Let's fix that") { advance() }) {
                painReveal
            }

        case .apps:
            chrome(primary: .init(title: "Continue") { advance() }) {
                appsQuestion
            }

        case .commitment:
            chrome(primary: .init(title: "Continue") { advance() }) {
                questionColumn(AppContent.commitQuestion) {
                    ForEach(AppContent.commitOptions) { opt in
                        OnbOptionRow(label: opt.label, note: opt.note,
                                     selected: answers.weeklyGoal == opt.perWeek) {
                            withAnimation(Motion.snappy) { answers.weeklyGoal = opt.perWeek }
                            Haptics.select()
                        }
                    }
                }
            }

        case .building:
            OnbBuildingView(onDone: advance, dotIndex: index, dotTotal: dotTotal)

        case .plan:
            chrome(primary: .init(title: "This is me") { advance() }) {
                OnbPlanView(answers: answers)
            }

        case .ritual:
            chrome(primary: .init(title: "Continue", enabled: answers.demoReady) { advance() }) {
                OnbRitualDemoView(answers: answers)
            }

        case .social:
            chrome(primary: .init(title: "Continue") { advance() }) {
                OnbSocialProofView()
            }

        case .notif:
            chrome(primary: .init(title: "Allow notifications") { requestNotifications() },
                   secondary: .init(title: "Maybe later") { advance() }) {
                VStack(spacing: 24) {
                    NotifStack(example: "Today, I choose calm over chaos.", mine: previewAffirmation)
                    VStack(spacing: 10) {
                        Text(loc: AppContent.notifTitle)
                            .font(Fonts.display(24, .bold)).foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.center)
                        Text(loc: AppContent.notifBody)
                            .font(Fonts.ui(14.5, .semibold)).foregroundStyle(Palette.inkSoft)
                            .multilineTextAlignment(.center).lineSpacing(3)
                    }
                    .padding(.horizontal, 8)
                }
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
            GeometryReader { geo in
                ScrollView {
                    content()
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geo.size.height, alignment: .center)
                        .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
            footer(primary: primary, secondary: secondary)   // pinned at the bottom
        }
        .padding(.horizontal, 26)
        .padding(.top, 8)
        .padding(.bottom, 30)
    }

    private func footer(primary: FooterButton, secondary: FooterLink?) -> some View {
        VStack(spacing: 18) {
            OnbDots(index: index, total: dotTotal)
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
        IconTileButton(icon: "chevron.left", size: 56, iconSize: 16,
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
                            in: RoundedRectangle(cornerRadius: DesignScale.s(17), style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DesignScale.s(17), style: .continuous)
                    .stroke(Palette.ink, lineWidth: b.enabled ? 2 : 0))
                .tactile(b.enabled ? 4 : 0, cornerRadius: DesignScale.s(17))
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

    // MARK: - Content builders

    private func narrative(_ kind: OnbKind, title: String? = nil, body: String? = nil) -> some View {
        VStack(spacing: 26) {
            OnbIllustration(kind: kind)
            if let title {
                VStack(spacing: 11) {
                    Text(loc: title)
                        .font(Fonts.display(27, .bold)).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center).lineSpacing(2)
                    if let body {
                        Text(loc: body)
                            .font(Fonts.ui(15.5, .semibold)).foregroundStyle(Palette.inkSoft)
                            .multilineTextAlignment(.center).lineSpacing(4)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private func questionColumn<Rows: View>(_ title: String, hint: String? = nil,
                                            @ViewBuilder rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                Text(loc: title)
                    .font(Fonts.display(26, .bold)).foregroundStyle(Palette.ink).lineSpacing(2)
                if let hint {
                    Text(loc: hint).font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSoft)
                }
            }
            .padding(.bottom, 22)

            VStack(spacing: 10) { rows() }
        }
    }

    private var painReveal: some View {
        VStack(spacing: 0) {
            Eyebrow(text: "Right now", tracking: 2, size: 13)
            Text("\(answers.painHours)")
                .font(Fonts.display(96, .heavy)).foregroundStyle(Palette.amber)
                .padding(.top, 8)
                .overlay(alignment: .topTrailing) {
                    InkGlyph(kind: .sparkle, size: 26, fill: Color(hex: "F6C33F"))
                        .offset(x: 26, y: 6).floaty(period: 4)
                }
            Text("hours a month")
                .font(Fonts.display(26, .bold)).foregroundStyle(Palette.ink)
            Text("handed to the scroll — gone before\nyou're even awake.")
                .font(Fonts.ui(16, .semibold)).foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center).lineSpacing(4)
                .padding(.top, 16)
        }
        .background { SoftGlow(color: Palette.amber, opacity: 0.14, size: 320) }
    }

    private var appsQuestion: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                Text(loc: AppContent.appsQuestion)
                    .font(Fonts.display(26, .bold)).foregroundStyle(Palette.ink).lineSpacing(2)
                Text(loc: AppContent.appsHint).font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSoft)
            }
            .padding(.bottom, 24)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 18) {
                ForEach(Brand.allCases) { b in
                    let picked = answers.isBrandPicked(b)
                    Button {
                        Haptics.select()
                        withAnimation(Motion.snappy) { answers.toggleBrand(b) }
                    } label: {
                        VStack(spacing: 7) {
                            BrandIcon(brand: b, size: 62)
                                .grayscale(picked ? 0 : 0.7)
                                .opacity(picked ? 1 : 0.55)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 62 * 0.23, style: .continuous)
                                        .stroke(Palette.ink, lineWidth: picked ? 3 : 0))
                            Text(b.displayName)
                                .font(Fonts.ui(11.5, .bold))
                                .foregroundStyle(picked ? Palette.ink : Palette.inkSofter)
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    // MARK: - Navigation

    private func advance() {
        guard index < beats.count - 1 else { return }
        forward = true
        withAnimation(Motion.gentle) { index += 1 }
        if beat == .building { answers.persist() }   // lock answers in before the paywall reads them
    }

    private func back() {
        guard index > 0 else { return }
        forward = false
        var target = index - 1
        if beats[target] == .building { target -= 1 }   // don't land on the auto-advancing build beat
        withAnimation(Motion.gentle) { index = max(0, target) }
    }

    private func requestNotifications() {
        Task {
            await AffirmationNudge.requestAuthorization()
            advance()
        }
    }

    private func finish() {
        answers.persist()
        if answers.demoReady {
            store.saveRitual(mood: answers.demoMood ?? 2, journal: answers.demoLine,
                              gratitudes: [answers.demoAffirmation])
        }
        SharedState.onboardingComplete = true
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

// MARK: - Option row (single = radio, multi = checkbox)

private struct OnbOptionRow: View {
    let label: String
    var note: String? = nil
    let selected: Bool
    var multi: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                indicator
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc: label).font(Fonts.ui(16, .heavy)).foregroundStyle(Palette.ink)
                    if let note {
                        Text(loc: note).font(Fonts.ui(12.5, .semibold)).foregroundStyle(Palette.inkSofter)
                    }
                }
                Spacer(minLength: 8)
            }
            .padding(15)
            .background(selected ? Color(hex: "FFF6E7") : Palette.cream,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(selected ? Palette.amber : Palette.ink.opacity(0.18), lineWidth: selected ? 2 : 1.5))
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    @ViewBuilder private var indicator: some View {
        ZStack {
            if multi {
                // Checkbox: amber fill + black ink outline when checked
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? Palette.amber : .clear)
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(selected ? Palette.ink : Palette.ink.opacity(0.3), lineWidth: 2)
                if selected {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                }
            } else {
                // Radio: amber ring + amber dot when selected
                Circle().stroke(selected ? Palette.amber : Palette.ink.opacity(0.3), lineWidth: 2)
                if selected { Circle().fill(Palette.amber).frame(width: 11, height: 11) }
            }
        }
        .frame(width: 22, height: 22)
    }
}

// MARK: - Building screen

private struct OnbBuildingView: View {
    var onDone: () -> Void
    let dotIndex: Int
    let dotTotal: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rise = false
    @State private var visibleTicks = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 26) {
                ZStack {
                    SoftGlow(color: Palette.sunDisc, opacity: 0.18, size: 240)
                    SunMark(size: 104).spin(period: 22)
                }
                .offset(y: rise ? 0 : 26)
                .opacity(rise ? 1 : 0.15)
                .floaty(period: 6)

                Text(loc: AppContent.buildingTitle)
                    .font(Fonts.display(23, .bold)).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 13) {
                    ForEach(Array(AppContent.buildingTicks.enumerated()), id: \.offset) { i, t in
                        HStack(spacing: 11) {
                            ZStack {
                                Circle().fill(i < visibleTicks ? Palette.amber : Color.white)
                                    .overlay(Circle().stroke(i < visibleTicks ? Palette.ink : Palette.ink.opacity(0.25),
                                                             lineWidth: 2))
                                    .frame(width: 26, height: 26)
                                if i < visibleTicks {
                                    Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy))
                                        .foregroundStyle(.white)
                                }
                            }
                            Text(loc: t).font(Fonts.ui(15, .bold))
                                .foregroundStyle(i < visibleTicks ? Palette.ink : Palette.inkSofter)
                        }
                        .opacity(i < visibleTicks ? 1 : 0.5)
                    }
                }
            }
            Spacer()
            VStack(spacing: 18) {
                OnbDots(index: dotIndex, total: dotTotal)
                // Reserves the same height the CTA button row occupies on every other beat, so the
                // dots land at the same vertical position here as everywhere else (this screen has
                // no buttons of its own — it auto-advances).
                Color.clear.frame(height: DesignScale.s(56))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
        .padding(.top, 8)
        .padding(.bottom, 30)
        .task { await run() }
    }

    private func run() async {
        if reduceMotion {
            rise = true; visibleTicks = AppContent.buildingTicks.count
            try? await Task.sleep(for: .seconds(0.5))
            onDone(); return
        }
        withAnimation(.easeOut(duration: 0.6)) { rise = true }
        for i in 1...AppContent.buildingTicks.count {
            try? await Task.sleep(for: .seconds(0.62))
            withAnimation(Motion.snappy) { visibleTicks = i }
        }
        try? await Task.sleep(for: .seconds(0.55))
        onDone()
    }
}

// MARK: - Plan reveal

private struct OnbPlanView: View {
    let answers: OnboardingAnswers

    var body: some View {
        VStack(spacing: 20) {
            Eyebrow(text: "Your mornings, redesigned", tracking: 1.6, size: 12)

            VStack(spacing: 3) {
                Text("≈ \(answers.reclaimedHours) hours")
                    .font(Fonts.display(48, .heavy)).foregroundStyle(Palette.amber)
                Text("a month, taken back from the scroll")
                    .font(Fonts.ui(14.5, .semibold)).foregroundStyle(Palette.inkSoft)
            }
            .multilineTextAlignment(.center)

            Text(loc: answers.primaryGoal.planEmpathy)
                .font(Fonts.display(19, .bold)).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)

            VStack(spacing: 14) {
                planRow(SunMark(size: 20), "The ritual",
                        "Mood → a 2-minute write → a few affirmations  ·  ~3 min")
                planRow(InkGlyph(kind: .moon, size: 20, fill: Palette.sunDisc, lineWidth: 1.6), "The quiet",
                        "Instagram, TikTok & X stay asleep until you've written")
                planRow(InkGlyph(kind: .flame, size: 19, fill: Palette.sunDisc, lineWidth: 1.6), "The goal",
                        "\(answers.weeklyGoal) mornings a week · a 30-day streak to make it stick")
            }
            .softCard(padding: 16, radius: 22, emphasized: true)
        }
        .background(alignment: .top) { SoftGlow(color: Palette.amber, opacity: 0.13, size: 300).offset(y: -10) }
    }

    private func planRow<G: View>(_ glyph: G, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(size: 38, fill: Palette.iconTile) { glyph }
            VStack(alignment: .leading, spacing: 3) {
                Text(loc: title).font(Fonts.ui(15, .heavy)).foregroundStyle(Palette.ink)
                Text(loc: body).font(Fonts.ui(12.5, .semibold)).foregroundStyle(Palette.inkSoft).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Ritual demo (one real rep — mood, a line, an affirmation — done live, not narrated)

private struct OnbRitualDemoView: View {
    @Bindable var answers: OnboardingAnswers
    @FocusState private var lineFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Try it, right now")
                    .font(Fonts.display(27, .bold)).foregroundStyle(Palette.ink)
                Text("Thirty seconds. This page is already yours.")
                    .font(Fonts.ui(14.5, .semibold)).foregroundStyle(Palette.inkSoft)
            }
            .padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("How are you, really?")
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { i in moodChoice(i) }
                }
            }
            .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("Empty your head — one line")
                TextField(LocalizedStringKey(AppContent.journalPlaceholder), text: $answers.demoLine, axis: .vertical)
                    .font(Fonts.ui(16, .semibold)).foregroundStyle(Palette.ink)
                    .lineLimit(2...4)
                    .focused($lineFocused)
                    .padding(14)
                    .background(Palette.cream, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Palette.ink.opacity(0.15), lineWidth: 1.5))
            }
            .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("Affirm yourself")
                HStack(spacing: 12) {
                    SunMark(size: 24, muted: answers.demoAffirmation.trimmingCharacters(in: .whitespaces).isEmpty)
                    TextField(LocalizedStringKey(AppContent.affirmationPlaceholder(0)), text: $answers.demoAffirmation)
                        .font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.ink)
                }
                .padding(14)
                .background(Palette.cream, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Palette.ink.opacity(0.15), lineWidth: 1.5))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fieldLabel(_ s: String) -> some View {
        Text(loc: s).font(Fonts.ui(13, .heavy)).foregroundStyle(Palette.inkSofter)
    }

    private func moodChoice(_ i: Int) -> some View {
        let selected = answers.demoMood == i
        return Button {
            Haptics.select()
            withAnimation(Motion.pop) { answers.demoMood = i }
        } label: {
            MoodFace(mood: i, size: 42, expressive: true)
                .opacity(answers.demoMood == nil || selected ? 1 : 0.4)
                .scaleEffect(selected ? 1.12 : 1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .animation(Motion.snappy, value: answers.demoMood)
    }
}

// MARK: - Notification cards — the original floating-card illustration, shown as a live stack of
// two: a generic example, then the line from the ritual demo (or the default), each arriving with
// its own reveal + notification sound.

private struct NotifCard: View {
    let text: String
    var time: String = "now"

    var body: some View {
        HStack(alignment: .top, spacing: DesignScale.s(12)) {
            Image("app-mark").resizable().scaledToFill()
                .frame(width: DesignScale.s(42), height: DesignScale.s(42))
                .clipShape(RoundedRectangle(cornerRadius: DesignScale.s(10), style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DesignScale.s(10), style: .continuous).stroke(Palette.ink.opacity(0.12), lineWidth: 1))
            VStack(alignment: .leading, spacing: DesignScale.s(3)) {
                HStack {
                    Text(loc: "Today's affirmation").font(Fonts.ui(14, .heavy)).foregroundStyle(Palette.ink)
                    Spacer()
                    Text(loc: time).font(Fonts.ui(12, .semibold)).foregroundStyle(Palette.inkSofter)
                }
                Text(loc: text)
                    .font(Fonts.ui(13.5, .semibold)).foregroundStyle(Color(hex: "5A4A38"))
                    .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(EdgeInsets(top: DesignScale.s(15), leading: DesignScale.s(15), bottom: DesignScale.s(15), trailing: DesignScale.s(16)))
        .frame(maxWidth: DesignScale.s(330))
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignScale.s(22), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DesignScale.s(22), style: .continuous).stroke(Palette.ink, lineWidth: 2))
        .shadow(color: Color(hex: "78501E").opacity(0.14), radius: DesignScale.s(16), y: DesignScale.s(9))
    }
}

private struct NotifStack: View {
    let example: String
    let mine: String
    @State private var showExample = false
    @State private var showMine = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 14) {
            if showMine {
                NotifCard(text: mine)
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                            removal: .opacity))
            }
            if showExample {
                NotifCard(text: example)
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                            removal: .opacity))
            }
        }
        .task { await run() }
    }

    private func run() async {
        guard !reduceMotion else {
            showMine = true; showExample = true
            Haptics.notificationSound()
            return
        }
        try? await Task.sleep(for: .seconds(0.3))
        withAnimation(Motion.snappy) { showMine = true }
        Haptics.notificationSound()
        try? await Task.sleep(for: .seconds(1.0))
        withAnimation(Motion.snappy) { showExample = true }
        Haptics.notificationSound()
    }
}

// MARK: - Social proof

private struct OnbSocialProofView: View {
    private var sp: SocialProof { AppContent.socialProof }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { _ in
                    InkGlyph(kind: .star, size: 28, fill: Color(hex: "F6C33F"), lineWidth: 1.4)
                }
            }
            if sp.hasStats {
                VStack(spacing: 2) {
                    Text(sp.rating).font(Fonts.display(40, .heavy)).foregroundStyle(Palette.ink)
                    if !sp.ratingsCount.isEmpty {
                        Text(sp.ratingsCount).font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSoft)
                    }
                }
            } else {
                Text("Loved at\nfirst light")
                    .font(Fonts.display(27, .bold)).foregroundStyle(Palette.ink)
            }

            if sp.quotes.isEmpty {
                VStack(spacing: 11) {
                    quoteCard("“Meet yourself before the world logs on.”",
                              "You're about to join people who reclaimed their mornings — one quiet page at a time.")
                    quoteCard("“The first ten minutes that are finally mine.”",
                              "The apps stay asleep until I've written — so the morning feels calm again.")
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(sp.quotes) { q in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("“\(q.text)”")
                                .font(Fonts.ui(15, .bold)).foregroundStyle(Palette.ink).lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("— \(q.author)")
                                .font(Fonts.ui(12.5, .semibold)).foregroundStyle(Palette.inkSofter)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .softCard(padding: 16)
                    }
                }
            }
        }
        // Glow anchored near the top (behind the stars/heading), so it stays put as the cards grow.
        .background(alignment: .top) { SoftGlow(color: Palette.sunDisc, opacity: 0.16, size: 300).offset(y: 40) }
    }

    private func quoteCard(_ quote: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(loc: quote)
                .font(Fonts.display(16, .semibold)).foregroundStyle(Palette.ink)
                .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            Text(loc: sub)
                .font(Fonts.ui(13, .semibold)).foregroundStyle(Palette.inkSoft)
                .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard(padding: 16, radius: 20, emphasized: true)
    }
}

// MARK: - Illustrations (one per slide kind) — retained from the original deck

private struct OnbIllustration: View {
    let kind: OnbKind

    var body: some View {
        switch kind {
        case .brand:  brand
        case .noise:  noise
        }
    }

    private var brand: some View {
        VStack(spacing: 0) {
            ZStack {
                SoftGlow(color: Palette.sunDisc, opacity: 0.22, size: 280)
                SunMark(size: 118).spin(period: 26)
                InkGlyph(kind: .sparkle, size: 24, fill: Color(hex: "F6C33F"))
                    .offset(x: -74, y: -60).floaty(period: 4)
                InkGlyph(kind: .heart, size: 20, fill: Color(hex: "F19DA6"))
                    .offset(x: 76, y: -44).floaty(period: 5, delay: 0.4)
            }
            .floaty(period: 6)
            .padding(.bottom, 22)
            Text("Honestly").font(Fonts.display(52, .heavy)).foregroundStyle(Palette.ink)
                .underlineSquiggle(Palette.amber, weight: 5, height: 12)
            Text("The quiet part of the morning — before the world logs on.")
                .font(Fonts.ui(16, .semibold)).foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center).lineSpacing(3)
                .frame(maxWidth: 280).padding(.top, 18)
        }
    }

    private static let notifDelays: [Double] = [0.1, 0.28, 0.46, 0.64]

    private var noise: some View {
        ZStack {
            notifChip(.instagram, "2 new likes on your photo", tilt: -4)
                .offset(x: DesignScale.s(-62), y: DesignScale.s(-92)).floaty(amplitude: 5, period: 3.4).popIn(delay: Self.notifDelays[0])
            notifChip(.tiktok, "24 new videos for you", tilt: 5)
                .offset(x: DesignScale.s(60), y: DesignScale.s(-32)).floaty(amplitude: 5, period: 3.8, delay: 0.2).popIn(delay: Self.notifDelays[1])
            notifChip(.snapchat, "New snap from a friend", tilt: -5)
                .offset(x: DesignScale.s(-60), y: DesignScale.s(32)).floaty(amplitude: 5, period: 3.2, delay: 0.4).popIn(delay: Self.notifDelays[2])
            notifChip(.whatsapp, "3 new messages", tilt: 4)
                .offset(x: DesignScale.s(62), y: DesignScale.s(92)).floaty(amplitude: 5, period: 3.6, delay: 0.1).popIn(delay: Self.notifDelays[3])
        }
        .frame(width: DesignScale.s(250), height: DesignScale.s(260))
        .task { await fireNotifHaptics() }
    }
    private func fireNotifHaptics() async {
        var elapsed = 0.0
        for delay in Self.notifDelays {
            try? await Task.sleep(for: .seconds(delay - elapsed))
            Haptics.tap()
            elapsed = delay
        }
    }
    private func notifChip(_ brand: Brand, _ teaser: String, tilt: Double) -> some View {
        HStack(spacing: DesignScale.s(9)) {
            BrandIcon(brand: brand, size: DesignScale.s(34))
            VStack(alignment: .leading, spacing: DesignScale.s(1)) {
                Text(brand.displayName).font(Fonts.ui(12.5, .heavy)).foregroundStyle(Palette.ink)
                Text(loc: teaser).font(Fonts.ui(11, .semibold)).foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
            }
        }
        .padding(EdgeInsets(top: DesignScale.s(9), leading: DesignScale.s(9), bottom: DesignScale.s(9), trailing: DesignScale.s(14)))
        .frame(width: DesignScale.s(192), alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: DesignScale.s(16), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DesignScale.s(16), style: .continuous).stroke(Palette.ink, lineWidth: 2))
        .shadow(color: Color(hex: "78501E").opacity(0.14), radius: DesignScale.s(12), y: DesignScale.s(7))
        .rotationEffect(.degrees(tilt))
    }
}
