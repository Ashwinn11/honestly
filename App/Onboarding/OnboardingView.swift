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

enum MorningAnswer: String, CaseIterable, Identifiable {
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

enum JournalAnswer: String, CaseIterable, Identifiable {
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
