import SwiftUI
import UIKit

struct RitualView: View {
    var onClose: () -> Void
    @Environment(JournalStore.self) private var store
    @Environment(PremiumManager.self) private var premium
    @Environment(AppFlow.self) private var flow

    @State private var step = 0
    @State private var mood: Int? = nil
    @State private var richText = NSAttributedString()
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var affirmations = ["", "", "", "", ""]
    @State private var tags: [String] = []
    @FocusState private var journalFocused: Bool
    @State private var promptIndex: Int = 0
    @State private var showImagePicker = false
    @State private var showTextColorPicker = false
    @State private var showHighlightPicker = false

    private var journalText: String { richText.string }
    private var wordCount: Int {
        journalText.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
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
                            // One continuous page for the whole ritual — no per-step cards. Most
                            // steps size to their actual content; the journal step alone claims the
                            // viewport so the writing surface does not collapse after the keyboard
                            // is dismissed.
                            JournalPageSurface(cornerRadius: 0, showsBinderHoles: false, bordered: false) {
                                stepBody(viewportHeight: proxy.size.height)
                                    .padding(EdgeInsets(top: 14, leading: 22, bottom: 24, trailing: 20))
                                    .frame(minHeight: step == 1 ? proxy.size.height : nil,
                                           alignment: .topLeading)
                            }
                            .capWidth(Metrics.maxContentWidth)
                        }
                        .scrollDismissesKeyboard(.interactively)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(PaperBackground())
                .safeAreaInset(edge: .bottom) {
                    // While the editor has focus, the footer becomes the formatting toolbar instead
                    // of the step CTA — same slot, same pattern as the rest of the ritual's chrome.
                    // The toolbar itself runs edge-to-edge (no horizontal margin) so its scrollable
                    // row gets full width; the CTA button keeps the page's usual side margin.
                    Group {
                        if journalFocused {
                            formattingToolbar
                        } else {
                            footer
                                .padding(.horizontal, 22)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 14)
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
        // Anchored here — not on the toolbar's photo button — because presenting this sheet steals
        // first-responder from the journal's UITextView, which flips `journalFocused` to false via
        // the `.focused()` binding. That swaps `formattingToolbar` (and the button this sheet used
        // to live on) out of the tree while `showImagePicker` is still true, tearing down the
        // presentation mid-flight and re-triggering it the moment the toolbar reappears — an
        // infinite present/dismiss loop. This root view never disappears, so the presentation is stable.
        .sheet(isPresented: $showImagePicker) {
            ImagePickerWithCrop(
                onImagePicked: { image in
                    insertPickedImage(image)
                    showImagePicker = false
                },
                onCancel: { showImagePicker = false }
            )
            .ignoresSafeArea()
        }
    }


    // MARK: Top bar — close icon + step title. On the journal step, the title slot becomes the
    // prompt itself (tap to shuffle) instead of a generic label — it doesn't compete with the
    // writing area below anymore, and it's real page content, unlike a title would be. No
    // progress dots, no mood badge here — the date/mood live on the page itself, below.
    private var topBar: some View {
        HStack(spacing: 12) {
            IconTileButton(icon: "xmark", size: 38, iconSize: 13) { onClose() }
            topBarTitleView
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .animation(Motion.gentle, value: step)
        .animation(Motion.snappy, value: promptIndex)
    }

    @ViewBuilder private var topBarTitleView: some View {
        if step == 1 {
            Button {
                if premium.isPremium { shufflePrompt() } else { flow.showPaywall() }
            } label: {
                Text(loc: premium.isPremium ? currentPromptText : "Unlock daily morning prompts")
                    .font(Fonts.display(14, .bold))
                    .foregroundStyle(premium.isPremium ? Palette.ink : Palette.inkSofter)
                    .lineSpacing(1)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .transition(.opacity)
        } else if let topBarTitle {
            Text(loc: topBarTitle)
                .font(Fonts.display(19, .bold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .transition(.opacity)
        }
    }

    private var topBarTitle: String? {
        switch step {
        case 0: return "How are you, really?"
        case 2: return "Affirm yourself"
        default: return nil
        }
    }

    // MARK: Scrollable content per step
    @ViewBuilder private func stepBody(viewportHeight: CGFloat) -> some View {
        switch step {
        case 0: moodBody
        case 1: journalBody(viewportHeight: viewportHeight)
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
                          enabled: !journalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
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

    // MARK: Step 1 — journal (the prompt lives in the top bar now — see topBarTitleView — so it
    // never competes with the writing area for space)
    private func journalBody(viewportHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PageDateRow(date: Date(), mood: mood)

            RichTextEditor(attributedText: $richText, isEditingAllowed: premium.isPremium,
                           selectedRange: $selectedRange, placeholder: "Start writing…")
                .focused($journalFocused)
                .frame(height: journalEditorHeight(for: viewportHeight))
                .padding(.top, 16)

            TagEditorRow(tags: $tags, isPremium: premium.isPremium, onLockTap: { flow.showPaywall() })
                .padding(.top, 16)

            // Only shown once there's something to report — the prompt above is the only guidance
            // the empty page needs.
            if wordCount > 0 {
                Text("\(wordCount) words — nice")
                    .font(Fonts.ui(12.5, .semibold)).foregroundStyle(Palette.inkSofter)
                    .padding(.top, 10)
            }
        }
        .onAppear {
            // Seed with today's daily prompt for this mood pool — stable all session, rotates daily.
            promptIndex = AppContent.dailyPromptIndex(in: promptPool)
        }
        .animation(Motion.gentle, value: wordCount > 0)
    }

    private func journalEditorHeight(for viewportHeight: CGFloat) -> CGFloat {
        let verticalPadding: CGFloat = 14 + 24
        let dateRowHeight: CGFloat = 24
        let editorTopPadding: CGFloat = 16
        let tagTopPadding: CGFloat = 16
        let tagRowHeight: CGFloat = 34
        let wordCounterHeight: CGFloat = wordCount > 0 ? 28 : 0
        let availableHeight = viewportHeight
            - verticalPadding
            - dateRowHeight
            - editorTopPadding
            - tagTopPadding
            - tagRowHeight
            - wordCounterHeight

        return max(220, availableHeight)
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
        store.saveRitual(mood: mood ?? 2, journal: journalText, affirmations: affirmations,
                          richContent: richText.rtfdData(), tags: tags)
        Haptics.success()
        withAnimation(Motion.gentle) { step = 3 }
    }

    // MARK: Formatting toolbar — swapped into the footer slot while the editor has focus.
    // Premium-gated exactly like the rest of the ritual: unlocked users get the real controls,
    // free users get a single locked row that opens the paywall.
    @ViewBuilder private var formattingToolbar: some View {
        if premium.isPremium {
            unlockedToolbar
        } else {
            lockedToolbar
        }
    }

    private var unlockedToolbar: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    toolbarButton(icon: "bold") { applyFormat { RichTextFormatting.toggleBold($0, range: $1) } }
                    toolbarButton(icon: "italic") { applyFormat { RichTextFormatting.toggleItalic($0, range: $1) } }
                    toolbarButton(icon: "underline") { applyFormat { RichTextFormatting.toggleUnderline($0, range: $1) } }
                    fontMenu
                    textColorMenu
                    highlightMenu
                    toolbarButton(icon: "photo") { showImagePicker = true }
                }
                // Scrolls away with the content (standard content-inset idiom) — matching leading
                // and trailing insets so the first (bold) and last (image) buttons both get the
                // same breathing room the rest of the row has between buttons.
                .padding(.horizontal, 16)
            }
            // Fixed, not scrolled — always reachable regardless of scroll position, since closing
            // the keyboard is a reliable action people expect to always be in the same spot. No
            // divider — the HStack spacing alone separates it cleanly from the image button.
            toolbarButton(icon: "keyboard.chevron.compact.down") { journalFocused = false }
                .padding(.trailing, 16)
        }
    }

    private var lockedToolbar: some View {
        Button { flow.showPaywall() } label: {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.inkSofter)
                Text(loc: "Unlock rich formatting — bold, colors, images")
                    .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSofter)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.hairline)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    private func toolbarIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Palette.ink)
            .frame(width: 36, height: 36)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Palette.outlineSoft, lineWidth: 1.2))
    }

    private func toolbarButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { toolbarIcon(icon) }
            .buttonStyle(PressableStyle(scale: 0.9))
    }

    private var fontMenu: some View {
        Menu {
            ForEach(FontChoice.allCases) { choice in
                Button(choice.rawValue) {
                    applyFormat { RichTextFormatting.setFont(choice, in: $0, range: $1) }
                }
            }
        } label: {
            toolbarIcon("textformat")
        }
    }

    // `Menu` forces its item icons to a monochrome system tint on iOS regardless of any
    // `.foregroundStyle` applied — a platform limitation, not something fixable within Menu. A
    // real popover with plain SwiftUI circles renders true colors instead.
    private var textColorMenu: some View {
        Button { showTextColorPicker = true } label: { toolbarIcon("character") }
            .buttonStyle(PressableStyle(scale: 0.9))
            .popover(isPresented: $showTextColorPicker, arrowEdge: .bottom) {
                colorSwatchRow(Self.textColorSwatches) { color in
                    applyFormat { RichTextFormatting.setTextColor(UIColor(color), in: $0, range: $1) }
                    showTextColorPicker = false
                }
                .padding(16)
                .presentationCompactAdaptation(.popover)
            }
    }

    private var highlightMenu: some View {
        Button { showHighlightPicker = true } label: { toolbarIcon("highlighter") }
            .buttonStyle(PressableStyle(scale: 0.9))
            .popover(isPresented: $showHighlightPicker, arrowEdge: .bottom) {
                HStack(spacing: 14) {
                    colorSwatchRow(Self.highlightSwatches) { color in
                        applyFormat { RichTextFormatting.setHighlight(UIColor(color), in: $0, range: $1) }
                        showHighlightPicker = false
                    }
                    Button {
                        applyFormat { RichTextFormatting.setHighlight(nil, in: $0, range: $1) }
                        showHighlightPicker = false
                    } label: {
                        Image(systemName: "circle.slash")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Palette.inkSofter)
                            .frame(width: 28, height: 28)
                            .overlay(Circle().stroke(Palette.ink.opacity(0.18), lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle(scale: 0.85))
                }
                .padding(16)
                .presentationCompactAdaptation(.popover)
            }
    }

    // No padding here — callers apply their own, since this is sometimes the sole popover
    // content (textColorMenu) and sometimes one of several siblings sharing an outer padded
    // HStack (highlightMenu). Padding baked in here doubled up in the latter case.
    private func colorSwatchRow(_ swatches: [Color], onPick: @escaping (Color) -> Void) -> some View {
        HStack(spacing: 14) {
            ForEach(Array(swatches.enumerated()), id: \.offset) { _, color in
                Button { onPick(color) } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(Palette.ink.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(PressableStyle(scale: 0.85))
            }
        }
    }

    private static let textColorSwatches: [Color] = [Palette.ink, Palette.amberDeep, Palette.danger, Palette.success]
    private static let highlightSwatches: [Color] =
        [Palette.sunDisc.opacity(0.4), Palette.mood(3).opacity(0.5), Palette.mood(4).opacity(0.4)]

    private func applyFormat(_ transform: (NSAttributedString, NSRange) -> NSAttributedString) {
        guard selectedRange.length > 0 else { return }
        richText = transform(richText, selectedRange)
        Haptics.select()
    }

    private func insertPickedImage(_ image: UIImage) {
        let resized = image.downscaledForJournal()
        let containerWidth = Metrics.maxContentWidth - 44   // approximates the editor's content width
        richText = RichTextFormatting.insertImage(resized, at: selectedRange.location,
                                                   containerWidth: containerWidth, in: richText)
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
