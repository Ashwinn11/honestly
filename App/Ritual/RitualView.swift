import SwiftUI
import UIKit

struct RitualView: View {
    var onClose: () -> Void
    @Environment(JournalStore.self) private var store
    @Environment(PremiumManager.self) private var premium
    @Environment(AppFlow.self) private var flow

    // 0: journal, 1: affirmations, 2: celebration — mood is no longer its own step; it's set
    // via the mood-card sheet, opened by tapping the mood icon on the journal page itself.
    @State private var step = 0
    @State private var mood: Int? = nil
    @State private var showMoodSheet = false
    @State private var richText = NSAttributedString()
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var affirmations = ["", "", "", "", ""]
    @State private var tags: [String] = []
    @FocusState private var journalFocused: Bool
    @State private var promptIndex: Int = 0
    @State private var showImagePicker = false
    @State private var showDoodleSheet = false
    @State private var showStickerSheet = false
    @State private var showThemeSheet = false
    @State private var theme: PageTheme = .paper

    private var journalText: String { richText.plainText }
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
            if step == 2 {
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
                                    .frame(minHeight: step == 0 ? proxy.size.height : nil,
                                           alignment: .topLeading)
                            }
                            .capWidth(Metrics.maxContentWidth)
                        }
                        .scrollDismissesKeyboard(.interactively)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(PageThemeBackground(theme: theme))
                .safeAreaInset(edge: .bottom) {
                    // While the editor has focus, the footer becomes the formatting toolbar instead
                    // of the step CTA — same slot, same pattern as the rest of the ritual's chrome.
                    // The toolbar itself runs edge-to-edge (no horizontal margin) so its scrollable
                    // row gets full width; the CTA button keeps the page's usual side margin.
                    Group {
                        if journalFocused {
                            EditorToolbar(
                                text: $richText,
                                selectedRange: $selectedRange,
                                onPhoto: { showImagePicker = true },
                                onDoodle: { showDoodleSheet = true },
                                onSticker: { showStickerSheet = true },
                                onTheme: { showThemeSheet = true },
                                onDismissKeyboard: { journalFocused = false }
                            )
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
        // All three media/theme sheets are anchored here — not on the toolbar buttons — for the
        // same reason as the photo sheet: presenting a sheet steals first-responder from the
        // UITextView, which flips `journalFocused` false and swaps the EditorToolbar (and its
        // buttons) out of the tree while the sheet is still presented, causing a present/dismiss
        // loop. This root view never disappears, so presentations are stable.
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
        .sheet(isPresented: $showDoodleSheet) {
            DoodleSheet { image in
                insertPickedImage(image)
            }
        }
        .sheet(isPresented: $showStickerSheet) {
            StickerPicker { image in
                let oldLength = richText.length
                let updated = RichTextFormatting.insertSticker(image, at: selectedRange.location,
                                                               in: richText)
                richText = updated
                // Advance the caret past what was just inserted — leaving it at the stale
                // pre-insert location put it right *before* the sticker, which is exactly the
                // "cursor touching an attachment" state that produces wrong font/line-height on
                // whatever gets typed next.
                selectedRange = NSRange(location: selectedRange.location + (updated.length - oldLength), length: 0)
            }
        }
        .sheet(isPresented: $showThemeSheet) {
            ThemePickerSheet(selection: $theme)
        }
        .sheet(isPresented: $showMoodSheet) {
            MoodPickerSheet(mood: $mood)
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
        if step == 0 {
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
        case 1: return "Affirm yourself"
        default: return nil
        }
    }

    // MARK: Scrollable content per step
    @ViewBuilder private func stepBody(viewportHeight: CGFloat) -> some View {
        switch step {
        case 0: journalBody(viewportHeight: viewportHeight)
        default: affirmationBody
        }
    }

    // MARK: Footer CTA per step — pinned at the bottom, floats above the keyboard
    @ViewBuilder private var footer: some View {
        switch step {
        case 0:
            PrimaryButton(title: "Almost there",
                          enabled: !journalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                journalFocused = false
                withAnimation(Motion.gentle) { step = 1 }
            }
        default:
            PrimaryButton(title: affirmCount >= 1 ? "Unlock my morning" : "Say at least one",
                          enabled: affirmCount >= 1) { finish() }
        }
    }

    // MARK: Step 0 — journal (the prompt lives in the top bar now — see topBarTitleView — so it
    // never competes with the writing area for space). Mood is set via the tappable icon on the
    // date row, which opens `MoodPickerSheet` — no longer a separate blocking step.
    private func journalBody(viewportHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PageDateRow(date: Date(), mood: mood) {
                Haptics.select()
                showMoodSheet = true
            }

            RichTextEditor(attributedText: $richText,
                           selectedRange: $selectedRange, placeholder: "Start writing…")
                .focused($journalFocused)
                .frame(height: journalEditorHeight(for: viewportHeight))
                .padding(.top, 16)

            TagEditorRow(tags: $tags)
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
        .onChange(of: mood) { _, _ in
            // Picking a mood (any time, since it's no longer a step gate) re-seeds the prompt
            // pool/index so the prompt actually reflects the mood just picked.
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

    // MARK: Step 1 — affirmations
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
        let thumbnail = richText.firstPhotoThumbnail()
        store.saveRitual(mood: mood ?? 2, journal: journalText, affirmations: affirmations,
                          richContent: richText.rtfdData(), tags: tags,
                          themeID: theme.rawValue, thumbnail: thumbnail)
        Haptics.success()
        withAnimation(Motion.gentle) { step = 2 }
    }

    private func insertPickedImage(_ image: UIImage) {
        let oldLength = richText.length
        let updated = RichTextFormatting.insertImage(image, at: selectedRange.location, in: richText)
        richText = updated
        // Same reasoning as the sticker sheet above — land the caret after the inserted block
        // (its trailing newline), not at the stale pre-insert location.
        selectedRange = NSRange(location: selectedRange.location + (updated.length - oldLength), length: 0)
    }
}

// MARK: - Mood card sheet — opened by tapping the mood icon on the journal page's date row.
// Replaces the old dedicated mood step; picking a face applies it and dismisses automatically.
private struct MoodPickerSheet: View {
    @Binding var mood: Int?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(loc: "How are you, really?")
                    .font(Fonts.display(19, .bold)).foregroundStyle(Palette.ink)
                Spacer()
                IconTileButton(icon: "xmark", size: 34, iconSize: 12) { dismiss() }
            }
            .padding(EdgeInsets(top: 18, leading: 20, bottom: 6, trailing: 20))

            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in moodChoice(i) }
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 26)
        }
        // Fill the whole sheet, not just the VStack's measured content height — otherwise the
        // background only paints up to the content and the system sheet's own (light gray)
        // background shows through underneath as a second layer, in the reserved bottom
        // safe-area/home-indicator strip a tight `.height()` detent still leaves.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.cream.ignoresSafeArea())
        .presentationDetents([.height(230)])
        .presentationDragIndicator(.hidden)
    }

    private func moodChoice(_ i: Int) -> some View {
        let selected = mood == i
        return Button {
            Haptics.select()
            withAnimation(Motion.pop) { mood = i }
            Task {
                try? await Task.sleep(for: .seconds(0.22))
                dismiss()
            }
        } label: {
            VStack(spacing: 9) {
                MoodFace(mood: i, size: 48, expressive: true)
                    .scaleEffect(selected ? 1.14 : 1)
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
}

// MARK: - Celebration (step 2)

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
