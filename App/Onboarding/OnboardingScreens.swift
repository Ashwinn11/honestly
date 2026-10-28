import SwiftUI

// The onboarding beats, one view each, in the order they play. The flow lives in OnboardingView.

struct OnbWelcomeView: View {
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

struct OnbMorningQuestionView: View {
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

struct OnbJournalQuestionView: View {
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

struct OnbAffirmationQuestionView: View {
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

struct OnbPersonalizedPlanView: View {
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


struct OnbChoiceRow: View {
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


// MARK: - Notification preview

/// A notification as it will arrive: its title, what it says, and when.
struct NotifCard<Message: View>: View {
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
struct OnbReminderView: View {
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

struct OnbSocialProofView: View {
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
