import SwiftUI

/// The morning ritual: mood → journal (with a shuffled prompt) → five gratitudes → celebration.
/// Matches `Honestly.dc.html` lines 284–371 and the finish/confetti logic. On finish it writes the
/// page through `JournalStore` (which lifts the shield) and shows the amber celebration.
struct RitualView: View {
    var onClose: () -> Void
    @Environment(JournalStore.self) private var store

    @State private var step = 0
    @State private var mood: Int? = nil
    @State private var journal = ""
    @State private var gratitudes = ["", "", "", "", ""]
    @State private var promptIdx = AppContent.defaultPromptIndex
    @FocusState private var journalFocused: Bool

    private var prompt: String { AppContent.prompts[promptIdx % AppContent.prompts.count] }
    private var wordCount: Int {
        journal.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
    private var gratCount: Int { gratitudes.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count }

    var body: some View {
        ZStack {
            if step == 3 {
                CelebrationView(mood: mood ?? 2, streak: store.streak,
                                summary: summary, onStart: onClose)
            } else {
                PaperBackground()
                VStack(spacing: 0) {
                    chrome
                    stepContent
                }
            }
        }
    }

    private var summary: String {
        let m = Mood(rawValue: mood ?? 2)?.label ?? "Sad"
        let g = gratCount == 1 ? "1 gratitude" : "\(gratCount) gratitudes"
        return "Mood: \(m)  ·  \(wordCount) words  ·  \(g)"
    }

    // MARK: Chrome (close + pips)
    private var chrome: some View {
        HStack(spacing: 14) {
            SoftCircleButton(icon: "xmark") { onClose() }
            RitualPips(step: step)
            Color.clear.frame(width: 38)
        }
        .padding(.top, 58)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    @ViewBuilder private var stepContent: some View {
        switch step {
        case 0: moodStep
        case 1: journalStep
        default: gratitudeStep
        }
    }

    // MARK: Step 0 — mood
    private var moodStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("How are you, really?").font(Fonts.display(31, .bold)).foregroundStyle(Palette.ink)
                Text("Before the day has an opinion. Tap what fits.")
                    .font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.inkSoft)
            }
            .padding(.top, 14)

            Spacer(minLength: 20)
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in moodChoice(i) }
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 20)

            PrimaryButton(title: mood != nil ? "That's my morning →" : "Tap how you feel",
                          enabled: mood != nil) {
                withAnimation(Motion.gentle) { step = 1 }
            }
        }
        .padding(EdgeInsets(top: 12, leading: 24, bottom: 26, trailing: 24))
    }

    private func moodChoice(_ i: Int) -> some View {
        let selected = mood == i
        let scale: CGFloat = selected ? 1.16 : (mood == nil ? 1 : 0.84)
        return Button {
            Haptics.select()
            withAnimation(Motion.pop) { mood = i }
        } label: {
            VStack(spacing: 9) {
                MoodFace(mood: i, size: 52)
                    .scaleEffect(scale)
                    .opacity(mood == nil || selected ? 1 : 0.4)
                Text(Mood(rawValue: i)!.label)
                    .font(Fonts.ui(12, selected ? .heavy : .semibold))
                    .foregroundStyle(selected ? Palette.mood(i) : Palette.inkSofter)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .animation(Motion.snappy, value: mood)
    }

    // MARK: Step 1 — journal
    private var journalStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Eyebrow(text: "Today's prompt", color: Palette.amber, tracking: 1.3, size: 11)
                    Text(prompt).font(Fonts.display(21, .semibold)).foregroundStyle(Palette.ink)
                        .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                }
                Spacer(minLength: 0)
                Button {
                    Haptics.tap()
                    withAnimation(Motion.snappy) { promptIdx += 1 }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.amber)
                        .frame(width: 40, height: 40)
                        .background(Palette.amber.opacity(0.13), in: Circle())
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.top, 12)

            RuledTextEditor(text: $journal, placeholder: AppContent.journalPlaceholder)
                .frame(minHeight: 190)
                .focused($journalFocused)
                .padding(.top, 14)

            Text(AppContent.journalHint(wordCount: wordCount))
                .font(Fonts.ui(12.5, .semibold)).foregroundStyle(Palette.inkSofter)
                .padding(.top, 12).padding(.horizontal, 2)

            PrimaryButton(title: "Almost there →",
                          enabled: !journal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                journalFocused = false
                withAnimation(Motion.gentle) { step = 2 }
            }
            .padding(.top, 12)
        }
        .padding(EdgeInsets(top: 12, leading: 22, bottom: 24, trailing: 22))
    }

    // MARK: Step 2 — gratitude
    private var gratitudeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Five small good things").font(Fonts.display(29, .bold)).foregroundStyle(Palette.ink)
                Text("The tinier and truer, the better.")
                    .font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.inkSoft)
            }
            .padding(.top, 12)

            Spacer(minLength: 18)
            VStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { i in gratitudeRow(i) }
            }
            Spacer(minLength: 18)

            PrimaryButton(title: gratCount >= 1 ? "Unlock my morning →" : "Add at least one",
                          enabled: gratCount >= 1) { finish() }
        }
        .padding(EdgeInsets(top: 12, leading: 22, bottom: 24, trailing: 22))
    }

    private func gratitudeRow(_ i: Int) -> some View {
        let lit = !gratitudes[i].trimmingCharacters(in: .whitespaces).isEmpty
        return HStack(spacing: 12) {
            SunMark(size: 26,
                    stroke: lit ? Palette.amber : Color(hex: "E4D9C4"),
                    fill: lit ? Palette.amberLight : nil)
                .scaleEffect(lit ? 1.12 : 1)
                .animation(Motion.pop, value: lit)
            TextField(AppContent.gratitudePlaceholder(i), text: $gratitudes[i])
                .font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.ink)
                .submitLabel(.next)
        }
        .padding(EdgeInsets(top: 11, leading: 14, bottom: 11, trailing: 14))
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color(hex: "78501E").opacity(0.06), radius: 8, y: 6)
    }

    // MARK: Finish
    private func finish() {
        store.saveRitual(mood: mood ?? 2, journal: journal, gratitudes: gratitudes, prompt: prompt)
        Haptics.success()
        withAnimation(Motion.gentle) { step = 3 }
    }
}

// MARK: - Ruled journal editor (paper lines behind the text)

private struct RuledTextEditor: View {
    @Binding var text: String
    let placeholder: String
    private let lineHeight: CGFloat = 32

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white)
            Canvas { ctx, size in
                var y = lineHeight
                while y < size.height {
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(p, with: .color(Palette.ink.opacity(0.07)), lineWidth: 1)
                    y += lineHeight
                }
            }
            TextEditor(text: $text)
                .font(Fonts.ui(16, .semibold))
                .foregroundStyle(Palette.ink)
                .lineSpacing(lineHeight - 20)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 11)
                .padding(.top, 5)
            if text.isEmpty {
                Text(placeholder)
                    .font(Fonts.ui(16, .medium)).foregroundStyle(Palette.inkMuted)
                    .padding(.horizontal, 16).padding(.top, 13)
                    .allowsHitTesting(false)
            }
        }
        .shadow(color: Color(hex: "78501E").opacity(0.07), radius: 11, y: 8)
    }
}

// MARK: - Celebration (step 3)

private struct CelebrationView: View {
    let mood: Int
    let streak: Int
    let summary: String
    var onStart: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.amber, Color(hex: "F0611A"), Color(hex: "E4551A")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            ConfettiBurst()

            VStack(spacing: 0) {
                ZStack {
                    RingPulse()
                    SunMark(size: 126, stroke: .white.opacity(0.55), fill: .white.opacity(0.55)).spin(period: 18)
                    MoodFace(mood: mood, size: 72)
                        .padding(10)
                        .background(.white, in: Circle())
                        .shadow(color: .black.opacity(0.2), radius: 14, y: 8)
                        .popIn(delay: 0.05)
                }
                .frame(height: 170)

                Text("Your apps are awake")
                    .font(Fonts.display(34, .heavy)).foregroundStyle(.white)
                    .multilineTextAlignment(.center).padding(.top, 16)
                Text("You showed up before the world did. That's the whole thing.")
                    .font(Fonts.ui(15.5, .semibold)).foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center).lineSpacing(2)
                    .frame(maxWidth: 290).padding(.top, 9)

                HStack(spacing: 14) {
                    Text("\(streak)").font(Fonts.display(40, .heavy)).foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("day streak").font(Fonts.ui(14, .heavy)).foregroundStyle(.white)
                        Text("+1 this morning").font(Fonts.ui(12, .semibold)).foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(.horizontal, 22).padding(.vertical, 12)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.25), lineWidth: 1))
                .padding(.top, 22)
                .popIn(delay: 0.35)

                Text(summary).font(Fonts.ui(12.5, .bold)).foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 16)

                Button { onStart() } label: {
                    Text("Start my day →")
                        .font(Fonts.ui(16.5, .heavy)).foregroundStyle(Palette.amber)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 12, y: 10)
                }
                .buttonStyle(PressableStyle())
                .frame(maxWidth: 320)
                .padding(.top, 26)
            }
            .padding(.horizontal, 28)
        }
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
