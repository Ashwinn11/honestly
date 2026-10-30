import SwiftUI

// The onboarding beats, one view each, in the order they play. The flow lives in OnboardingView.

struct OnbWelcomeView: View {
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                SoftGlow(color: Palette.sunDisc, opacity: 0.22, size: 280)
                Image("app-mark")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 118, height: 118)
                    .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 27, style: .continuous)
                        .strokeBorder(Palette.ink, lineWidth: 2))
                    .shadow(color: Palette.ink.opacity(0.12), radius: 12, x: 0, y: 7)
                    .accessibilityHidden(true)
                InkGlyph(kind: .sparkle, size: 24, fill: Palette.glyphGold)
                    .offset(x: -74, y: -60)
                    .floaty(period: 4)
                InkGlyph(kind: .heart, size: 20, fill: Palette.glyphBlush)
                    .offset(x: 76, y: -44)
                    .floaty(period: 5, delay: 0.4)
            }
            .floaty(period: 6)
            .padding(.bottom, 30)
            OnbHeader(eyebrow: "Honestly", title: "Your journal opens before your apps do.")
        }
    }
}

struct OnbMorningQuestionView: View {
    @Binding var selection: [MorningAnswer]

    var body: some View {
        VStack(spacing: 18) {
            OnbHeader(eyebrow: "Your mornings", title: "How do most of your mornings start?",
                      hint: "Pick any that sound like you.")
            VStack(spacing: 9) {
                ForEach(MorningAnswer.allCases) { answer in
                    ChoiceRow(title: answer.title, selected: selection.contains(answer)) {
                        Haptics.select()
                        selection.toggle(answer)
                    }
                }
            }
        }
    }
}

struct OnbJournalQuestionView: View {
    @Binding var selection: [JournalAnswer]

    var body: some View {
        VStack(spacing: 18) {
            OnbHeader(eyebrow: "Your journaling", title: "What usually gets in the way of journaling?",
                      hint: "Pick any.")
            VStack(spacing: 9) {
                ForEach(JournalAnswer.allCases) { answer in
                    ChoiceRow(title: answer.title, selected: selection.contains(answer)) {
                        Haptics.select()
                        selection.toggle(answer)
                    }
                }
            }
        }
    }
}

struct OnbAffirmationQuestionView: View {
    @Binding var picks: [String]
    let sample: String

    var body: some View {
        VStack(spacing: 0) {
            OnbHeader(eyebrow: "Your affirmations", title: "What would you like to hear more often?")
                .padding(.bottom, 18)
            AffirmationTopicPicker(selection: $picks, onSelection: { Haptics.select() }, collapsedCount: 6)
                .padding(.bottom, 12)
            Eyebrow(text: "Today's affirmation", tracking: 1.4, size: 11)
                .padding(.bottom, 8)
            OnbAffirmationPreview(text: sample, topic: picks.last ?? "")
        }
    }
}

struct OnbPersonalizedPlanView: View {
    let title: String
    let affirmation: String
    /// What Honestly does about each answer, one line apiece.
    let promises: [String]

    var body: some View {
        VStack(spacing: 24) {
            OnbHeader(eyebrow: "Your mornings, with Honestly", title: title)
            MorningOutcomeCard(affirmation: affirmation)
                .rotationEffect(.degrees(-4))
            VStack(alignment: .leading, spacing: 11) {
                ForEach(promises, id: \.self) { line in
                    HStack(alignment: .top, spacing: 10) {
                        SunMark(size: 17, rays: false)
                            .padding(.top, 1)
                        Text(loc: line)
                            .font(Fonts.ui(14.5, .semibold))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: 310)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .background(alignment: .center) {
            SoftGlow(color: Palette.sunDisc, opacity: 0.14, size: 300)
        }
    }
}


private extension Array where Element: Equatable {
    /// Adds the answer, or takes it back out — keeping the order they were picked in.
    mutating func toggle(_ element: Element) {
        if let at = firstIndex(of: element) { remove(at: at) } else { append(element) }
    }
}

// MARK: - Notification preview

/// A notification as it will arrive: its title, what it says, and when.
struct NotifCard<Message: View>: View {
    let title: String                    // String Catalog key
    let time: String
    @ViewBuilder var message: Message

    var body: some View {
        HStack(alignment: .center, spacing: DesignScale.s(12)) {
            Image("app-mark").resizable().scaledToFill()
                .frame(width: DesignScale.s(42), height: DesignScale.s(42))
                .clipShape(RoundedRectangle(cornerRadius: DesignScale.s(Radius.tile), style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DesignScale.s(Radius.tile), style: .continuous).strokeBorder(Palette.ink.opacity(0.12), lineWidth: 1))
            VStack(alignment: .leading, spacing: DesignScale.s(3)) {
                HStack(alignment: .firstTextBaseline) {
                    Text(loc: title).font(Fonts.ui(14, .heavy)).foregroundStyle(Palette.ink)
                    Spacer()
                    Text(verbatim: time).font(Fonts.ui(12, .semibold)).foregroundStyle(Palette.inkSofter)
                        .contentTransition(.numericText())
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

/// When tomorrow's page should be ready, set the way Notification reminders sets it — a list
/// whose times open the system picker — then the two notifications as they'll arrive: the
/// writing page's prompt when the day's page is still blank, and the day's affirmation.
struct OnbReminderView: View {
    @Binding var journalMinutes: Int
    @Binding var affirmationMinutes: Int
    let prompt: String
    let affirmation: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingAnimationsActive) private var animationsActive
    @State private var visibleCount = 0

    var body: some View {
        VStack(spacing: 20) {
            OnbHeader(eyebrow: "Tomorrow morning", title: "When should your page be ready?")
            VStack(spacing: 0) {
                TimeRow(title: "Journal reminder", detail: "Only on mornings your page is still blank.",
                        minutes: $journalMinutes)
                Rectangle().fill(Palette.outlineSoft).frame(height: 1)
                    .padding(.vertical, 12)
                TimeRow(title: "Affirmation reminder", minutes: $affirmationMinutes)
            }
            .panelCard()
            VStack(spacing: 12) {
                if visibleCount > 0 {
                    NotifCard(title: "Journal reminder", time: Self.clock(journalMinutes)) {
                        Text(verbatim: prompt)
                    }
                    .transition(arrival)
                }
                if visibleCount > 1 {
                    NotifCard(title: "Today's affirmation", time: Self.clock(affirmationMinutes)) {
                        Affirmations.text(affirmation)
                    }
                    .transition(arrival)
                }
            }
        }
        .task(id: animationsActive) {
            visibleCount = 0
            guard animationsActive else { return }
            await revealNotifications()
        }
    }

    private var arrival: AnyTransition {
        .asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity)
    }

    /// A time of day in the app's language — 8:00 PM, 20:00.
    static func clock(_ minutes: Int) -> String {
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
            try await Task.sleep(for: .milliseconds(180))
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

// MARK: - After a purchase: the apps that wait

/// Straight after buying, the app blocking they just paid for — before they land on Home.
struct OnbChooseAppsView: View {
    let chosen: Bool

    var body: some View {
        VStack(spacing: 24) {
            OnbHeader(eyebrow: "Your mornings",
                      title: chosen ? "Your apps will wait each morning until you’ve written."
                                    : "Choose the apps that wait")
            AppBlockLoop()
        }
        .background { SoftGlow(color: Palette.sunDisc, opacity: 0.16, size: 300) }
    }
}
