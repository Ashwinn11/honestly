import SwiftUI
import WidgetKit
import FamilyControls

private struct OnboardingAnimationsActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var onboardingAnimationsActive: Bool {
        get { self[OnboardingAnimationsActiveKey.self] }
        set { self[OnboardingAnimationsActiveKey.self] = newValue }
    }
}

struct OnboardingView: View {
    var onFinish: () -> Void

    @Environment(AffirmationList.self) private var affirmations
    @Environment(PremiumManager.self) private var premium
    @Environment(JournalStore.self) private var store
    @Environment(PromptLibrary.self) private var prompts
    @Environment(ScreenTimeManager.self) private var screenTime
    @Environment(AppFlow.self) private var flow
    @Environment(\.openURL) private var openURL

    @State private var index = 0
    @State private var forward = true
    @State private var picks: [String] = []
    @State private var morningAnswers: [MorningAnswer] = []
    @State private var journalAnswers: [JournalAnswer] = []
    @State private var reminderMinutes = AffirmationNudge.journalReminderMinutes
    @State private var affirmationMinutes = AffirmationNudge.times.first ?? AffirmationNudge.defaultMinutes
    @State private var showAppPicker = false
    @State private var showScreenTimeHelp = false
    @State private var onboardingAnimationsActive = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Beat: Int, CaseIterable {
        case brand, morning, journaling, affirmations, personal, notif, paywall, chooseApps
    }
    private let beats = Beat.allCases
    private var beat: Beat { beats[index] }

    /// The dots count the screens before the paywall; what follows a purchase isn't counted.
    private var dotTotal: Int { Beat.paywall.rawValue }
    private var canGoBack: Bool { index > 0 && beat != .chooseApps }

    var body: some View {
        ZStack {
            PaperBackground()
            if beat == .paywall {
                PaywallView(onClose: finish, onPurchased: purchased)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                beatView
                    .id(index)
                    .transition(slide)
                    .capWidth(Metrics.maxContentWidth)
            }
        }
        .environment(\.onboardingAnimationsActive, onboardingAnimationsActive)
        .animation(Motion.snappy, value: index)
        .onAppear {
            picks = affirmations.selectedTopics
            morningAnswers = MorningAnswer.saved
            journalAnswers = JournalAnswer.saved
        }
        .task(id: index) {
            onboardingAnimationsActive = false
            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(420))
                guard !Task.isCancelled else { return }
            }
            onboardingAnimationsActive = true
        }
        .onChange(of: flow.ritualPresented) { _, presented in
            // Back from their first page, written or not: on to when tomorrow's should be ready.
            if !presented && beat == .personal { advance() }
        }
        .familyActivityPicker(isPresented: $showAppPicker, selection: Binding(
            get: { screenTime.selection }, set: { screenTime.selection = $0 }))
        .alert("Screen Time access is off", isPresented: $showScreenTimeHelp) {
            Button("Open Settings") { openURL(URL(string: UIApplication.openSettingsURLString)!) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(loc: "Allow Screen Time access, then choose the apps you want to hold.")
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
            chrome(primary: .init(title: "Let’s begin") { advance() }) {
                OnbWelcomeView()
            }

        case .morning:
            chrome(primary: .init(title: "Continue", enabled: !morningAnswers.isEmpty) {
                MorningAnswer.saved = morningAnswers
                advance()
            }) {
                OnbMorningQuestionView(selection: $morningAnswers)
            }

        case .journaling:
            chrome(primary: .init(title: "Continue", enabled: !journalAnswers.isEmpty) {
                JournalAnswer.saved = journalAnswers
                advance()
            }) {
                OnbJournalQuestionView(selection: $journalAnswers)
            }

        case .affirmations:
            chrome(primary: .init(title: "Continue") {
                affirmations.setSelectedTopics(picks)
                advance()
            }) {
                OnbAffirmationQuestionView(picks: $picks, sample: sampleAffirmation)
            }

        case .personal:
            // An invitation to the real page, never a step: "later" is always as easy as "now",
            // and a page already written today is never opened again from here.
            if store.ritualDoneToday {
                chrome(primary: .init(title: "Continue") { advance() }) { plan }
            } else {
                chrome(primary: .init(title: "Open my first page") { openFirstPage() },
                       secondary: .init(title: "I’ll write later") { advance() }) { plan }
            }

        case .notif:
            chrome(primary: .init(title: "Turn on reminders") { requestNotifications() },
                   secondary: .init(title: "Not now") {
                       saveReminderTimes()
                       advance()
                   }) {
                OnbReminderView(journalMinutes: $reminderMinutes,
                                affirmationMinutes: $affirmationMinutes,
                                prompt: tomorrowPrompt,
                                affirmation: reminderSamples.first ?? sampleAffirmation)
            }

        case .paywall:
            EmptyView()   // handled at the top level

        case .chooseApps:
            if screenTime.hasSelection {
                chrome(primary: .init(title: "Continue") { finish() }) {
                    OnbChooseAppsView(chosen: true)
                }
            } else {
                // Screen Time access comes first; the app list opens straight after it's approved.
                chrome(primary: .init(title: screenTime.authorized ? "Choose apps" : "Approve Screen Time") { chooseApps() },
                       secondary: .init(title: "Not now") { finish() }) {
                    OnbChooseAppsView(chosen: false)
                }
            }
        }
    }

    private var plan: some View {
        OnbPersonalizedPlanView(title: planTitle, affirmation: sampleAffirmation, promises: planPromises)
    }

    // MARK: - Shared chrome (content, then the footer as part of the page — nothing is pinned)

    @ViewBuilder
    private func chrome<C: View>(primary: FooterButton,
                                 secondary: FooterLink? = nil,
                                 @ViewBuilder content: @escaping () -> C) -> some View {
        VStack(spacing: 0) {
            if beat == .brand {
                LanguagePickerPill()
                    .padding(.top, 6)
                    .padding(.bottom, 14)
            }
            if index < dotTotal {
                OnbDots(index: index, total: dotTotal)
                    .padding(.top, beat == .brand ? 0 : 8)
                    .padding(.bottom, 8)
            }
            GeometryReader { geo in
                ScrollView {
                    // The footer ends the page: at the bottom when the content is short, and after
                    // it — scrolling with it — when the content runs long.
                    VStack(spacing: 0) {
                        Spacer(minLength: 12)
                        content()
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 26)   // padding lives here so shadows bleed freely
                        Spacer(minLength: 28)
                        footer(primary: primary, secondary: secondary)
                            .padding(.horizontal, 26)
                    }
                    .padding(.bottom, 30)
                    .frame(minHeight: geo.size.height)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .padding(.top, 8)
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

    // MARK: - What the answers become

    private var sampleAffirmation: String {
        if sampleAffirmationTopic == "Your own", premium.allows(.ownAffirmations) {
            return affirmations.savedCustom.first ?? "You deserve care and kindness."
        }
        let topic = sampleAffirmationTopic
        let lines = affirmations.availableLibrary.first(where: { $0.title == topic })?.lines ?? []
        // A first impression should be easy to believe: lead with the topic's gentlest line.
        if let gentle = Self.gentleLines[topic], lines.contains(gentle) { return gentle }
        return lines.first
            ?? affirmations.availableLibrary.first?.lines.first
            ?? "You deserve care and kindness."
    }

    private var sampleAffirmationTopic: String {
        picks.last ?? affirmations.availableLibrary.first?.title ?? ""
    }

    /// One believable line per topic — "I can…" rather than "I am…" — for the onboarding previews.
    private static let gentleLines: [String: String] = [
        "Self-worth": "I am learning to love myself exactly as I am.",
        "Calm": "I can take a breath when I feel overwhelmed.",
        "Worry & fear": "I am learning to trust myself more than my fears.",
        "Confidence": "I can become more confident one step at a time.",
        "Gratitude": "I can find reasons to be grateful even on ordinary days.",
        "Happiness": "I can make room for joy again when I am ready.",
        "Hard times": "I can make it through a day that feels difficult.",
        "Growth": "I can make progress even when I take things slowly.",
        "Motivation": "I can motivate myself to take the next step.",
        "Courage": "I can choose courage over self-doubt.",
        "Contentment": "I give myself time to enjoy simple things.",
        "Success": "I can be successful without rushing or stressing.",
        "Relationships": "I am learning to be a better friend to myself.",
        "Health": "I can take care of my body and mind.",
        "Money": "I choose abundance over scarcity.",
        "Everyday": "I can start again tomorrow if today feels too hard.",
    ]

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

    // The first morning answer (where app blocking speaks) titles the plan.
    private var planTitle: String {
        morningAnswers.first?.summaryTitle ?? "A morning with more room for you."
    }

    /// What the plan promises back: one line for the mornings, one for the journaling, then the
    /// day's kind word. A journaling line that repeats the morning one is left out.
    private var planPromises: [String] {
        var lines: [String] = []
        if let morning = morningAnswers.first { lines.append(morning.promise) }
        if let journal = journalAnswers.first(where: { !$0.echoes(morningAnswers.first) }) {
            lines.append(journal.promise)
        }
        lines.append("Then a kind word to carry into your day.")
        return lines
    }

    private var tomorrowPrompt: String {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        return prompts.pageText(on: tomorrow)
            ?? L10n.localized("Write today's page — a few quiet minutes, just for you.")
    }

    // MARK: - Navigation

    private func advance() {
        guard index < beats.count - 1 else { return }
        onboardingAnimationsActive = false
        forward = true
        withAnimation(Motion.gentle) {
            index += 1
            if skips(beat) { index += 1 }
        }
    }

    private func back() {
        guard index > 0 else { return }
        onboardingAnimationsActive = false
        forward = false
        withAnimation(Motion.gentle) {
            index = max(0, index - 1)
            if skips(beat) { index = max(0, index - 1) }
        }
    }

    /// Someone who bought Premium from inside their first page isn't asked again.
    private func skips(_ beat: Beat) -> Bool {
        beat == .paywall && premium.isPremium
    }

    /// The real writing page — the same one Home opens — on the question their journaling answer
    /// chose. They can still tap it for another, and close the page whenever they like.
    private func openFirstPage() {
        if let line = journalAnswers.first?.firstPrompt { prompts.select(line) }
        flow.startRitual()
    }

    /// Both times are kept whether or not notifications are allowed; Notification reminders shows them.
    private func saveReminderTimes() {
        AffirmationNudge.setJournalReminderMinutes(reminderMinutes)
        var times = AffirmationNudge.times
        guard times.first != affirmationMinutes else { return }
        if times.isEmpty { times = [affirmationMinutes] } else { times[0] = affirmationMinutes }
        SharedState.defaults.set(times, forKey: SharedState.Key.affirmationReminderTimes)
        AffirmationNudge.schedule()
    }

    private func requestNotifications() {
        saveReminderTimes()
        Task {
            // Allowing notifications here turns the reminders on — the screen just promised them.
            if await AffirmationNudge.requestPermission() { AffirmationNudge.enable() }
            advance()
        }
    }

    /// A purchase made here goes straight to choosing the apps it unlocked, unless they're chosen.
    private func purchased() {
        if screenTime.hasSelection { finish() } else { advance() }
    }

    private func chooseApps() {
        Task {
            if await screenTime.ensureAuthorizedForPicker() { showAppPicker = true }
            else { showScreenTimeHelp = true }
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

struct OnbDots: View {
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
struct OnbHeader: View {
    let eyebrow: String
    let title: String
    var hint: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            Eyebrow(text: eyebrow, tracking: 1.6, size: 12)
            Text(loc: title)
                .font(Fonts.display(24, .bold))
                .foregroundStyle(Palette.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            if let hint {
                Text(loc: hint)
                    .font(Fonts.ui(13.5, .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }
}

// MARK: - The answers

enum MorningAnswer: String, CaseIterable, Identifiable {
    case phone, racingMind, rushing, routine
    var id: String { rawValue }
    var title: String {
        switch self {
        case .phone: "I reach for my phone first"
        case .racingMind: "My mind is already racing"
        case .rushing: "I rush into everyone else’s needs"
        case .routine: "I keep meaning to start a routine"
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
    /// What Honestly does about it, on the plan.
    var promise: String {
        switch self {
        case .phone: "Your chosen apps stay asleep until you’ve written."
        case .racingMind: "Your thoughts get somewhere to land before the day starts."
        case .rushing: "A few minutes that are yours, before anyone else’s."
        case .routine: "A journal reminder at the time you pick, only if your page is blank."
        }
    }
    /// The paywall's headline for someone who starts their mornings this way.
    var paywallTitle: String {
        switch self {
        case .phone: "Write first. Scroll later."
        case .racingMind: "Mornings with room to think."
        case .rushing: "Mornings that start with you."
        case .routine: "A morning ritual you’ll keep."
        }
    }

    /// The answers from onboarding, in the order they were picked — the paywall reads them later.
    static var saved: [MorningAnswer] {
        get { (UserDefaults.standard.stringArray(forKey: "onboarding.morningAnswers") ?? []).compactMap(Self.init) }
        set { UserDefaults.standard.set(newValue.map(\.rawValue), forKey: "onboarding.morningAnswers") }
    }
}

enum JournalAnswer: String, CaseIterable, Identifiable {
    case blankPage, time, tangled, consistency
    var id: String { rawValue }
    var title: String {
        switch self {
        case .blankPage: "I don’t know what to write"
        case .time: "I can’t find the time"
        case .tangled: "My thoughts feel too tangled"
        case .consistency: "I start, then stop coming back"
        }
    }
    /// What Honestly does about it, on the plan.
    var promise: String {
        switch self {
        case .blankPage: "A new question waits on your page each morning."
        case .time: "Three honest lines make a page."
        case .tangled: "Your page gives tangled thoughts somewhere to go."
        case .consistency: "Your book keeps every page, even after a gap."
        }
    }
    /// The question their first page opens on — from the prompt bank, and right at any hour.
    var firstPrompt: String {
        switch self {
        case .blankPage: "What's the quietest thing on your mind right now?"
        case .time: "What feels heavy? What feels light?"
        case .tangled: "What's been sitting in the back of your mind?"
        case .consistency: "What's the one thing that would make today feel like a win?"
        }
    }
    /// Racing and tangled thoughts make the same promise; the plan says it once.
    func echoes(_ morning: MorningAnswer?) -> Bool {
        self == .tangled && morning == .racingMind
    }

    static var saved: [JournalAnswer] {
        get { (UserDefaults.standard.stringArray(forKey: "onboarding.journalAnswers") ?? []).compactMap(Self.init) }
        set { UserDefaults.standard.set(newValue.map(\.rawValue), forKey: "onboarding.journalAnswers") }
    }
}
