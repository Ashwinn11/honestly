import SwiftUI

struct RitualView: View {
    var onClose: () -> Void
    @Environment(JournalStore.self) private var store

    @State private var step = 0
    @State private var mood: Int? = nil
    @State private var journal = ""
    @State private var affirmations = ["", "", "", "", ""]
    @FocusState private var journalFocused: Bool

    private var wordCount: Int {
        journal.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
    private var affirmCount: Int { affirmations.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count }

    var body: some View {
        if step == 3 {
            CelebrationView(mood: mood ?? 2, streak: store.streak,
                            words: wordCount, affirmCount: affirmCount, onStart: onClose)
        } else {
            VStack(spacing: 0) {
                header.capWidth(Metrics.maxContentWidth)
                ScrollView {
                    stepBody
                        .padding(.horizontal, 22)
                        .padding(.top, 6)
                        .padding(.bottom, 8)
                        .capWidth(Metrics.maxContentWidth)   // centered column; PaperBackground stays full
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(PaperBackground())
            .safeAreaInset(edge: .bottom) {
                footer
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .padding(.bottom, 14)
                    .background(Palette.paper)
            }
        }
    }


    // MARK: Header (close + progress) — pinned at the top
    private var header: some View {
        HStack(spacing: 14) {
            IconTileButton(icon: "xmark", size: 38, iconSize: 13) { onClose() }
            RitualPips(step: step)
            Color.clear.frame(width: 38, height: 38)   // balances the close button (fixed height!)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
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
            Text("How are you, really?").font(Fonts.display(31, .bold)).foregroundStyle(Palette.ink)
            Text("Before the day has an opinion. Tap what fits.")
                .font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.inkSoft).padding(.top, 8)
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in moodChoice(i) }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            Text("Empty your head").font(Fonts.display(29, .bold)).foregroundStyle(Palette.ink)
            Text("No prompts, no rules. Just write.")
                .font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.inkSoft).padding(.top, 7)

            RuledTextEditor(text: $journal, placeholder: AppContent.journalPlaceholder)
                .focused($journalFocused)
                .padding(.top, 20)

            (wordCount == 0 ? Text("This page is just for you.") : Text("\(wordCount) words — nice"))
                .font(Fonts.ui(12.5, .semibold)).foregroundStyle(Palette.inkSofter)
                .padding(.top, 12).padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Step 2 — affirmations
    private var affirmationBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Affirm yourself").font(Fonts.display(29, .bold)).foregroundStyle(Palette.ink)
            Text("Say it like you already believe it.")
                .font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.inkSoft).padding(.top, 7)
            VStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { i in affirmationRow(i) }
            }
            .padding(.top, 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func affirmationRow(_ i: Int) -> some View {
        let lit = !affirmations[i].trimmingCharacters(in: .whitespaces).isEmpty
        return HStack(spacing: 12) {
            SunMark(size: 26, muted: !lit)
                .scaleEffect(lit ? 1.08 : 1)
                .animation(Motion.pop, value: lit)
            TextField(LocalizedStringKey(AppContent.affirmationPlaceholder(i)), text: $affirmations[i])
                .font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.ink)
                .submitLabel(.next)
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .background(lit ? Palette.cream : .white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(lit ? Palette.outlineSoft : Palette.ink.opacity(0.12), lineWidth: 1.5))
    }

    // MARK: Finish
    private func finish() {
        store.saveRitual(mood: mood ?? 2, journal: journal, gratitudes: affirmations)
        Haptics.success()
        withAnimation(Motion.gentle) { step = 3 }
        AffirmationNudge.scheduleNext(from: store.entries.flatMap(\.gratitudes))
    }
}

// MARK: - Ruled journal editor — the editable form of the shared `RuledPaper`

private struct RuledTextEditor: View {
    @Binding var text: String
    let placeholder: String
    static let lineHeight: CGFloat = 32
    static let height: CGFloat = 176      // fixed — the field scrolls internally instead of growing

    var body: some View {
        RuledPaper(lineHeight: Self.lineHeight) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(Fonts.ui(16, .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(Self.lineHeight - 20)
                    .tint(Palette.amber)
                    .scrollContentBackground(.hidden)   // let the ruled paper show through
                    .padding(.horizontal, 11)           // + TextEditor's 5pt fragment inset ≈ 16
                    .padding(.vertical, 8)
                    .frame(height: Self.height)

                if text.isEmpty {
                    Text(loc: placeholder)
                        .font(Fonts.ui(16, .semibold))
                        .foregroundStyle(Palette.inkSofter)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }
            }
        }
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
