import SwiftUI
import FamilyControls

struct OnboardingView: View {
    var onFinish: () -> Void

    @Environment(ScreenTimeManager.self) private var screenTime

    @State private var answers = OnboardingAnswers()
    @State private var index = 0
    @State private var forward = true
    @State private var showPicker = false

    private enum Beat: Int, CaseIterable {
        case brand, problem, goal, scroll, pain, apps, commitment, building, plan, ritual, social, notif, paywall
    }
    private let beats = Beat.allCases
    private var beat: Beat { beats[index] }

    private var dotTotal: Int { beats.count - 1 }
    private var canGoBack: Bool { index > 0 && beat != .building }

    var body: some View {
        @Bindable var st = screenTime
        ZStack {
            PaperBackground()
            if beat == .paywall {
                PaywallView(gate: true, onClose: finish)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                beatView
                    .id(index)
                    .transition(slide)
                    .capWidth(Metrics.maxContentWidth)
            }
        }
        .animation(Motion.gentle, value: index)
        .familyActivityPicker(isPresented: $showPicker, selection: $st.selection)
        .onChange(of: showPicker) { _, presented in
            if !presented { advance() }        // picker dismissed → move past the apps beat
        }
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
            chrome(primary: .init(title: "Choose apps to quiet") { chooseApps() },
                   secondary: .init(title: "Not now") { advance() }) {
                narrative(.quiet, title: AppContent.onbQuietTitle, body: AppContent.onbQuietBody)
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
            chrome(primary: .init(title: "Continue") { advance() }) {
                OnbRitualTeachView()
            }

        case .social:
            chrome(primary: .init(title: "Continue") { advance() }) {
                OnbSocialProofView()
            }

        case .notif:
            chrome(primary: .init(title: "Allow notifications") { requestNotifications() },
                   secondary: .init(title: "Maybe later") { advance() }) {
                narrative(.notif, title: AppContent.notifTitle, body: AppContent.notifBody)
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
                        Text(secondary.title)
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
            Text(b.title)
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
                    Text(title)
                        .font(Fonts.display(27, .bold)).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center).lineSpacing(2)
                    if let body {
                        Text(body)
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
                Text(title)
                    .font(Fonts.display(26, .bold)).foregroundStyle(Palette.ink).lineSpacing(2)
                if let hint {
                    Text(hint).font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSoft)
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
                Text(AppContent.appsQuestion)
                    .font(Fonts.display(26, .bold)).foregroundStyle(Palette.ink).lineSpacing(2)
                Text(AppContent.appsHint).font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSoft)
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
                                        .stroke(Palette.amber, lineWidth: picked ? 3 : 0))
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

    private func chooseApps() {
        Task {
            if await screenTime.ensureAuthorizedForPicker() { showPicker = true }
            else { advance() }
        }
    }

    private func requestNotifications() {
        Task {
            if await MorningNudge.requestAuthorization() { MorningNudge.schedule() }
            advance()
        }
    }

    private func finish() {
        answers.persist()
        screenTime.armSchedule()
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
                    Text(label).font(Fonts.ui(16, .heavy)).foregroundStyle(Palette.ink)
                    if let note {
                        Text(note).font(Fonts.ui(12.5, .semibold)).foregroundStyle(Palette.inkSofter)
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

                Text(AppContent.buildingTitle)
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
                            Text(t).font(Fonts.ui(15, .bold))
                                .foregroundStyle(i < visibleTicks ? Palette.ink : Palette.inkSofter)
                        }
                        .opacity(i < visibleTicks ? 1 : 0.5)
                    }
                }
            }
            Spacer()
            OnbDots(index: dotIndex, total: dotTotal)
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

            Text(answers.primaryGoal.planEmpathy)
                .font(Fonts.display(19, .bold)).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)

            VStack(spacing: 14) {
                planRow(SunMark(size: 20), "The ritual",
                        "Mood → a 2-minute write → 5 gratitudes  ·  ~3 min")
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
                Text(title).font(Fonts.ui(15, .heavy)).foregroundStyle(Palette.ink)
                Text(body).font(Fonts.ui(12.5, .semibold)).foregroundStyle(Palette.inkSoft).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Ritual teach (three steps in one screen)

private struct OnbRitualTeachView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Your 3-minute\nritual")
                    .font(Fonts.display(27, .bold)).foregroundStyle(Palette.ink)
                Text("Three small steps, every morning.")
                    .font(Fonts.ui(14.5, .semibold)).foregroundStyle(Palette.inkSoft)
            }
            .padding(.bottom, 24)

            VStack(spacing: 14) {
                ForEach(Array(AppContent.ritualSteps.enumerated()), id: \.element.id) { i, step in
                    HStack(spacing: 15) {
                        glyph(step.kind)
                            .frame(width: 52, height: 52)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.title).font(Fonts.ui(16, .heavy)).foregroundStyle(Palette.ink)
                            Text(step.body).font(Fonts.ui(13.5, .semibold)).foregroundStyle(Palette.inkSoft)
                                .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .softCard(padding: 15, radius: 20)
                    .staggeredAppear(index: i)
                }
            }
        }
    }

    @ViewBuilder private func glyph(_ kind: OnbKind) -> some View {
        switch kind {
        case .moods:
            MoodFace(mood: 0, size: 48)
        case .write:
            VStack(alignment: .leading, spacing: 8) {
                lineCap(0.95, Color(hex: "FFE0B4"))
                lineCap(1.0, Palette.ink.opacity(0.2))
                lineCap(0.6, Palette.amber)
            }
            .frame(width: 46)
        case .grat:
            SunMark(size: 44)
        default:
            SunMark(size: 44)
        }
    }
    private func lineCap(_ frac: CGFloat, _ c: Color) -> some View {
        GeometryReader { g in
            Capsule().fill(c)
                .overlay(Capsule().stroke(Palette.ink, lineWidth: 1.5))
                .frame(width: g.size.width * frac, height: 8)
        }
        .frame(height: 8)
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
                    quoteCard("Meet yourself before the world logs on.",
                              "You're about to join people who reclaimed their mornings — one quiet page at a time.")
                    quoteCard("The first ten minutes that are finally mine.",
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
            Text("“\(quote)”")
                .font(Fonts.display(16, .semibold)).foregroundStyle(Palette.ink)
                .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            Text(sub)
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

    private var noise: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Palette.ink).frame(width: 118, height: 230)
                .shadow(color: Palette.ink.opacity(0.24), radius: 17, y: 9)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "4A3A2A")).frame(width: 100, height: 210)
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
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Palette.ink, lineWidth: 2.5))
            .tactile(5, cornerRadius: 13, color: Palette.ink.opacity(0.15))
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
        HStack(alignment: .center, spacing: 12) {
            SleepingAppTile(brand: .instagram, size: 58, tilt: -8).floaty(period: 3.4)
            SleepingAppTile(brand: .snapchat, size: 58, tilt: 5).floaty(period: 3.0, delay: 0.2)
            SleepingAppTile(brand: .x, size: 58, tilt: -4).floaty(period: 3.6, delay: 0.4)
            SleepingAppTile(brand: .whatsapp, size: 58, tilt: 8).floaty(period: 3.2, delay: 0.1)
        }
        .background { SoftGlow(color: Palette.sunDisc, opacity: 0.16, size: 300) }
    }

    private var streak: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 8) {
                sun(26, 0.4); sun(34, 0.55); sun(44, 0.7); sun(56, 0.85)
                SunMark(size: 72).floaty(period: 3)
            }
            .padding(.bottom, 20)
            Text("12").font(Fonts.display(60, .heavy)).foregroundStyle(Palette.amber)
            Eyebrow(text: "days and counting", color: Palette.inkSofter, tracking: 1, size: 13).padding(.top, 2)
        }
    }
    private func sun(_ s: CGFloat, _ op: Double) -> some View { SunMark(size: s).opacity(op) }

    private var notif: some View {
        HStack(alignment: .top, spacing: 12) {
            Image("app-mark").resizable().scaledToFill()
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Palette.ink.opacity(0.12), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Honestly").font(Fonts.ui(14, .heavy)).foregroundStyle(Palette.ink)
                    Spacer()
                    Text("now").font(Fonts.ui(12, .semibold)).foregroundStyle(Palette.inkSofter)
                }
                Text("Good morning. Your page is waiting — the world can hold on a minute.")
                    .font(Fonts.ui(13.5, .semibold)).foregroundStyle(Color(hex: "5A4A38"))
                    .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(EdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 16))
        .frame(width: 330)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Palette.ink, lineWidth: 2))
        .shadow(color: Color(hex: "78501E").opacity(0.14), radius: 16, y: 9)
        .floaty(period: 5)
    }

    private var ready: some View {
        ZStack {
            SunMark(size: 24).offset(x: -70, y: -50).floaty(period: 4)
            SunMark(size: 18).offset(x: 74, y: -14).floaty(period: 5, delay: 0.4)
            SunMark(size: 130).spin(period: 24).floaty(period: 6)
        }
        .frame(height: 180)
    }
}

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
