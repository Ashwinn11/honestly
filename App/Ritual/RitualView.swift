import SwiftUI

struct RitualView: View {
    var onClose: () -> Void
    @Environment(JournalStore.self) private var store
    @Environment(PremiumManager.self) private var premium
    @Environment(AppFlow.self) private var flow

    @State private var step = 0
    @State private var mood: Int? = nil
    @State private var journal = ""
    @State private var affirmations = ["", "", "", "", ""]
    @FocusState private var journalFocused: Bool
    @State private var promptIndex: Int = 0
    @State private var promptDismissed: Bool = false

    private var wordCount: Int {
        journal.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
    private var affirmCount: Int { affirmations.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count }

    // MARK: Prompt helpers
    private var promptPool: [JournalPrompt] { AppContent.prompts(for: mood) }
    private var currentPromptText: String {
        guard !promptPool.isEmpty else { return "" }
        return promptPool[promptIndex % promptPool.count].text
    }
    private func shufflePrompt() {
        guard promptPool.count > 1 else { return }
        var next: Int
        repeat { next = Int.random(in: 0..<promptPool.count) }
        while next == promptIndex % promptPool.count
        withAnimation(Motion.snappy) { promptIndex = next }
        Haptics.select()
    }

    var body: some View {
        @Bindable var flow = flow
        Group {
            if step == 3 {
                CelebrationView(mood: mood ?? 2, streak: store.streak,
                                words: wordCount, affirmCount: affirmCount, onStart: onClose)
            } else {
                VStack(spacing: 0) {
                    topBar.capWidth(Metrics.maxContentWidth)
                    GeometryReader { proxy in
                        ScrollView {
                            // One continuous page for the whole ritual — no per-step cards. minHeight
                            // keeps the cream/ruled fill covering the full viewport even on short steps
                            // (mirrors EntryDetailView's JournalReaderPage), so there's no seam where
                            // paper peeks through below a short step.
                            JournalPageSurface(lineHeight: 32, cornerRadius: 0, showsMargin: false,
                                               showsBinderHoles: false, bordered: false) {
                                stepBody
                                    .padding(EdgeInsets(top: 14, leading: 22, bottom: 24, trailing: 20))
                                    .frame(minHeight: proxy.size.height, alignment: .topLeading)
                            }
                            .capWidth(Metrics.maxContentWidth)
                        }
                        .scrollDismissesKeyboard(.interactively)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(PaperBackground())
                .safeAreaInset(edge: .bottom) {
                    footer
                        .padding(.horizontal, 22)
                        .padding(.top, 8)
                        .padding(.bottom, 14)
                        .background(Palette.cream)   // matches the page fill — no seam below the CTA
                }
            }
        }
        // RitualView is itself a fullScreenCover off RootView, which also owns a fullScreenCover
        // for the paywall — presenting from the same presenter while it's already presenting Ritual
        // silently queues until Ritual dismisses. Attaching a second copy here lets the paywall
        // present on top of Ritual directly, so an in-progress entry isn't lost.
        .fullScreenCover(isPresented: $flow.paywallPresented) {
            PaywallView(onClose: { flow.paywallPresented = false })
        }
    }


    // MARK: Top bar — close icon + (for mood/affirm steps only) the step title. Nothing else: no
    // progress dots, no mood badge here — the date/mood live on the page itself, below.
    private var topBar: some View {
        HStack(spacing: 12) {
            IconTileButton(icon: "xmark", size: 38, iconSize: 13) { onClose() }
            if let topBarTitle {
                Text(loc: topBarTitle)
                    .font(Fonts.display(19, .bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .animation(Motion.gentle, value: step)
    }

    private var topBarTitle: String? {
        switch step {
        case 0: return "How are you, really?"
        case 1: return "Write what's true"
        default: return "Affirm yourself"
        }
    }

    // MARK: Scrollable content per step
    @ViewBuilder private var stepBody: some View {
        switch step {
        case 0: moodBody
        case 1: journalBody
        default: affirmationBody
        }
    }

    // MARK: Footer CTA per step — pinned at the bottom, floats above the keyboard
    @ViewBuilder private var footer: some View {
        switch step {
        case 0:
            PrimaryButton(title: mood != nil ? "That's my morning" : "Tap how you feel",
                          enabled: mood != nil) {
                withAnimation(Motion.gentle) { step = 1 }
            }
        case 1:
            PrimaryButton(title: "Almost there",
                          enabled: !journal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                journalFocused = false
                withAnimation(Motion.gentle) { step = 2 }
            }
        default:
            PrimaryButton(title: affirmCount >= 1 ? "Unlock my morning" : "Say at least one",
                          enabled: affirmCount >= 1) { finish() }
        }
    }

    // MARK: Step 0 — mood
    private var moodBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageDateRow(date: Date(), mood: mood)
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in moodChoice(i) }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 28)
        }
    }

    private func moodChoice(_ i: Int) -> some View {
        let selected = mood == i
        let scale: CGFloat = selected ? 1.16 : (mood == nil ? 1 : 0.84)
        return Button {
            Haptics.select()
            withAnimation(Motion.pop) { mood = i }
        } label: {
            VStack(spacing: 9) {
                MoodFace(mood: i, size: 52, expressive: true)
                    .scaleEffect(scale)
                    .opacity(mood == nil || selected ? 1 : 0.42)
                Text(loc: Mood(rawValue: i)!.label)
                    .font(Fonts.ui(12, selected ? .heavy : .semibold))
                    .foregroundStyle(selected ? Palette.amberDeep : Palette.inkSofter)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .animation(Motion.snappy, value: mood)
    }

    // MARK: Step 1 — journal
    private var journalBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageDateRow(date: Date(), mood: mood)

            // Prompt: hidden once the user starts writing (premium) or on explicit dismiss. Free
            // users see a locked teaser that opens the paywall on tap. No card — just page text.
            if !promptDismissed && !(premium.isPremium && wordCount > 0) {
                JournalPromptChip(
                    text: currentPromptText,
                    isPremium: premium.isPremium,
                    onShuffle: shufflePrompt,
                    onDismiss: { withAnimation(Motion.gentle) { promptDismissed = true } },
                    onLockTap: { flow.showPaywall() }
                )
                .padding(.top, 18)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            RuledJournalEditor(text: $journal)
                .focused($journalFocused)
                .padding(.top, 16)

            // Only shown once there's something to report — the prompt above is the only guidance
            // the empty page needs.
            if wordCount > 0 {
                Text("\(wordCount) words — nice")
                    .font(Fonts.ui(12.5, .semibold)).foregroundStyle(Palette.inkSofter)
                    .padding(.top, 8)
            }
        }
        .onAppear {
            // Seed with today's daily prompt for this mood pool — stable all session, rotates daily.
            promptIndex = AppContent.dailyPromptIndex(in: promptPool)
            promptDismissed = false
        }
        .animation(Motion.gentle, value: wordCount > 0)
    }

    // MARK: Step 2 — affirmations
    private var affirmationBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageDateRow(date: Date(), mood: mood)
            VStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { i in affirmationRow(i) }
            }
            .padding(.top, 20)
        }
    }

    @ViewBuilder
    private func affirmationRow(_ i: Int) -> some View {
        if i > 0 && !premium.isPremium {
            lockedAffirmationRow
        } else {
            let lit = !affirmations[i].trimmingCharacters(in: .whitespaces).isEmpty
            HStack(spacing: 12) {
                SunMark(size: 26, muted: !lit)
                    .scaleEffect(lit ? 1.08 : 1)
                    .animation(Motion.pop, value: lit)
                TextField(LocalizedStringKey(AppContent.affirmationPlaceholder(i)), text: $affirmations[i])
                    .font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.ink)
                    .submitLabel(.next)
            }
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
            .background(lit ? Palette.iconTile : .white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(lit ? Palette.outlineSoft : Palette.ink.opacity(0.12), lineWidth: 1.5))
        }
    }

    private var lockedAffirmationRow: some View {
        Button { flow.showPaywall() } label: {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.inkSofter)
                    .frame(width: 26, height: 26)
                Text(loc: "Unlock more affirmations")
                    .font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.inkSofter)
                Spacer(minLength: 0)
            }
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Palette.ink.opacity(0.12), lineWidth: 1.5))
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    // MARK: Finish
    private func finish() {
        store.saveRitual(mood: mood ?? 2, journal: journal, gratitudes: affirmations)
        Haptics.success()
        withAnimation(Motion.gentle) { step = 3 }
    }
}

// MARK: - Journal prompt (premium: the question itself, printed plainly · free: locked teaser)
// No card, no icon — a real journal page doesn't box or decorate its own printed question, it's
// just posed to you directly on the paper.

private struct JournalPromptChip: View {
    let text: String
    let isPremium: Bool
    let onShuffle: () -> Void
    let onDismiss: () -> Void
    let onLockTap: () -> Void

    var body: some View {
        if isPremium {
            premiumPrompt
        } else {
            lockedPrompt
        }
    }

    // The question, bold ink, given real weight — with quiet shuffle/dismiss controls alongside
    private var premiumPrompt: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(loc: text)
                .font(Fonts.ui(16.5, .bold))
                .foregroundStyle(Palette.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                Button(action: onShuffle) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.inkSofter)
                }
                .buttonStyle(PressableStyle(scale: 0.88))

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.inkSofter)
                }
                .buttonStyle(PressableStyle(scale: 0.88))
            }
            .padding(.top, 3)
        }
    }

    // Same plain-text layout, just locked — tap anywhere opens the paywall
    private var lockedPrompt: some View {
        Button(action: onLockTap) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.inkSofter)

                Text(loc: "Unlock daily morning prompts")
                    .font(Fonts.ui(15, .semibold))
                    .foregroundStyle(Palette.inkSofter)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.hairline)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }
}

// MARK: - Ruled journal editor — the writing surface, laid directly on the shared page

private struct RuledJournalEditor: View {
    @Binding var text: String
    static let lineHeight: CGFloat = 32
    static let height: CGFloat = 220      // fixed — the field scrolls internally instead of growing

    // No placeholder — the prompt above already poses the question. An empty-state line here
    // would just repeat it.
    var body: some View {
        TextEditor(text: $text)
            .font(Fonts.ui(16, .semibold))
            .foregroundStyle(Palette.ink)
            .lineSpacing(Self.lineHeight - 20)
            .tint(Palette.amber)
            .scrollContentBackground(.hidden)   // let the journal page show through
            .padding(.horizontal, 11)           // + TextEditor's 5pt fragment inset ≈ 16
            .padding(.vertical, 4)
            .frame(height: Self.height)
    }
}

// MARK: - Celebration (step 3)

private struct CelebrationView: View {
    let mood: Int
    let streak: Int
    let words: Int
    let affirmCount: Int
    var onStart: () -> Void

    @Environment(\.requestReview) private var requestReview

    var body: some View {
        ZStack {
            Palette.celebrationGradient.ignoresSafeArea()
            ConfettiBurst()
            celebrationDecor

            VStack(spacing: 0) {
                ZStack {
                    RingPulse()
                    SunMark(size: 116, disc: false).spin(period: 18)   // black rays only
                    MoodFace(mood: mood, size: 72, expressive: true)
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                        .popIn(delay: 0.05)
                }
                .frame(height: 170)

                Text("Your apps are awake")
                    .font(Fonts.display(34, .heavy)).foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: Color(hex: "78280A").opacity(0.3), radius: 14, y: 2)
                    .padding(.top, 12)
                Text("You showed up before the world did. That's the whole thing.")
                    .font(Fonts.ui(15.5, .semibold)).foregroundStyle(.white.opacity(0.94))
                    .multilineTextAlignment(.center).lineSpacing(2)
                    .frame(maxWidth: 290).padding(.top, 10)

                HStack(spacing: 13) {
                    Text("\(streak)").font(Fonts.display(38, .heavy)).foregroundStyle(Palette.ink)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("day streak").font(Fonts.ui(14, .heavy)).foregroundStyle(Palette.ink)
                        Text("+1 this morning").font(Fonts.ui(12, .bold)).foregroundStyle(Palette.amberDeep)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(Palette.onAmber, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.ink, lineWidth: 2))
                .tactile(6, cornerRadius: 16)
                .padding(.top, 22)
                .popIn(delay: 0.35)

                Text("Mood: \(Text(loc: Mood(rawValue: mood)?.label ?? "Sad"))  ·  \(words) words  ·  \(affirmCount) affirmations")
                    .font(Fonts.ui(12.5, .bold)).foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 18)

                CreamButton(title: "Start my day") { onStart() }
                    .frame(maxWidth: 300)
                    .padding(.top, 22)
            }
            .padding(.horizontal, 28)
            .capWidth(Metrics.maxContentWidth)   // centered column; gradient stays full-bleed
        }
        .task {
            try? await Task.sleep(for: .seconds(1.2))
            ReviewPrompt.maybeAsk(streak: streak, requestReview)
        }
    }

    // Static floating decor, layered under the content (ConfettiBurst handles the motion).
    private var celebrationDecor: some View {
        ZStack {
            InkGlyph(kind: .sparkle, size: 26, fill: Color(hex: "F6C33F"))
                .rotationEffect(.degrees(-12)).offset(x: -118, y: -228).floaty(period: 4)
            InkGlyph(kind: .heart, size: 22, fill: Color(hex: "F19DA6"))
                .offset(x: 112, y: -248).floaty(period: 5, delay: 0.3)
            InkGlyph(kind: .sparkle, size: 18, fill: Color(hex: "8FB6E0"))
                .offset(x: -104, y: 118).floaty(period: 4.5, delay: 0.2)
            Circle().fill(.white.opacity(0.85)).frame(width: 7, height: 7).offset(x: -72, y: -176)
            Circle().fill(Color(hex: "FFF3D6")).frame(width: 6, height: 6).offset(x: -118, y: 158)
            Circle().fill(.white.opacity(0.8)).frame(width: 6, height: 6).offset(x: 92, y: -138)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

private struct RingPulse: View {
    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Circle()
            .fill(.white.opacity(0.18))
            .frame(width: 150, height: 150)
            .scaleEffect(animate ? 1.9 : 0.7)
            .opacity(animate ? 0 : 0.5)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.9).repeatForever(autoreverses: false)) { animate = true }
            }
    }
}
