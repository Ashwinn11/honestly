import SwiftUI
import UIKit

struct RitualView: View {
    var onClose: () -> Void
    @Environment(JournalStore.self) private var store
    @Environment(PremiumManager.self) private var premium
    @Environment(AppFlow.self) private var flow
    @Environment(PromptLibrary.self) private var prompts
    @Environment(AffirmationList.self) private var affirmations

    // 0: journal, 1: celebration — mood is no longer its own step; it's set via the mood-card
    // sheet, opened by tapping the mood icon on the journal page itself. Affirmations aren't
    // written here anymore either: the celebration shows the day's line from the picked rotation.
    @State private var step = 0
    @State private var mood: Int? = ScreenshotPreview.screen == "write" ? 0 : nil
    @State private var showMoodSheet = false
    @State private var richText = ScreenshotPreview.screen == "write"
        ? NSAttributedString(string: ScreenshotPreview.journal,
                             attributes: [.font: UIFont(name: "Manrope-Medium", size: 17) ?? .systemFont(ofSize: 17)])
        : NSAttributedString()
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var tags: [String] = []
    @State private var showTagsSheet = false
    @FocusState private var journalFocused: Bool
    @State private var showPromptPicker = false
    @State private var showImagePicker = false
    @State private var showDoodleSheet = false
    @State private var showStickerSheet = false
    @State private var showThemeSheet = false
    @State private var showFormattingSheet = false
    @State private var theme: PageTheme = .paper

    private var editorSheetPresented: Bool {
        showFormattingSheet || showTagsSheet || showImagePicker || showDoodleSheet || showStickerSheet || showThemeSheet || showPromptPicker || showMoodSheet || flow.paywallPresented
    }

    private var journalText: String { richText.plainText }
    private var wordCount: Int {
        journalText.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    var body: some View {
        @Bindable var flow = flow
        Group {
            if step == 1 {
                CelebrationView(mood: mood ?? 0, streak: store.streak, words: wordCount,
                                affirmation: affirmations.today(premium: premium.isPremium),
                                onStart: onClose)
            } else {
                VStack(spacing: 0) {
                    topBar.capWidth(Metrics.maxContentWidth)
                    // One continuous page for the whole ritual — no per-step cards. Every step
                    // (including the journal editor, which grows to its actual content height —
                    // see `RichTextEditor`) sizes to its real content, so this one `ScrollView` is
                    // the only scrolling region; nothing needs the viewport height threaded in.
                    ScrollView {
                        JournalPageSurface(cornerRadius: 0, showsBinderHoles: false, bordered: false) {
                            journalBody
                                .padding(EdgeInsets(top: 14, leading: Metrics.pageHorizontalInset,
                                                    bottom: 24, trailing: Metrics.pageHorizontalInset))
                        }
                        .capWidth(Metrics.maxContentWidth)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(PageThemeBackground(theme: theme))
                .safeAreaInset(edge: .bottom) {
                    // While the editor has focus, the footer becomes the formatting toolbar instead
                    // of the step CTA — same slot, same pattern as the rest of the ritual's chrome.
                    // The toolbar itself runs edge-to-edge (no horizontal margin) so its scrollable
                    // row gets full width; the CTA button keeps the page's usual side margin.
                    VStack(spacing: 0) {
                            EditorToolbar(
                                text: $richText,
                                selectedRange: $selectedRange,
                                tagCount: tags.count,
                                onTags: { showTagsSheet = true },
                                onPhoto: { showImagePicker = true },
                                onDoodle: { showDoodleSheet = true },
                                onSticker: { showStickerSheet = true },
                                onTheme: { showThemeSheet = true },
                                onDismissKeyboard: { journalFocused = false },
                                onFormattingOpened: { showFormattingSheet = true; journalFocused = false },
                                onFormattingClosed: { showFormattingSheet = false; journalFocused = true }
                            )
                            .frame(height: journalFocused ? nil : 0)
                            .clipped()
                            .opacity(journalFocused ? 1 : 0)
                            .allowsHitTesting(journalFocused)
                            .accessibilityHidden(!journalFocused)
                        if !journalFocused {
                            footer.padding(.horizontal, 22)
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
        .onChange(of: editorSheetPresented) { _, presented in
            if presented { journalFocused = false }
        }
        .fullScreenCover(isPresented: $showPromptPicker) {
            PromptLibraryScreen()
        }
        .sheet(isPresented: $showTagsSheet, onDismiss: { journalFocused = true }) {
            TagEditorSheet(tags: $tags)
        }
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


    // MARK: Top bar — close icon and tappable prompt library
    // it doesn't compete with the writing area below, and it's real page content, unlike a title
    // would be. No progress dots, no mood badge here — the date/mood live on the page itself, below.
    private var topBar: some View {
        HStack(spacing: 10) {
            IconTileButton(icon: "xmark", size: 38, iconSize: 13) { onClose() }
            topBarTitleView
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .animation(Motion.gentle, value: step)
    }

    private var topBarTitleView: some View {
        Button {
            journalFocused = false
            if premium.isPremium { showPromptPicker = true } else { flow.showPaywall() }
        } label: {
            HStack(spacing: 10) {
                Group {
                    if premium.isPremium, let line = prompts.selected {
                        if prompts.builtIn.contains(line) { Text(loc: line) }
                        else { Text(verbatim: line) }
                    } else {
                        Text(loc: premium.isPremium ? "Choose a prompt" : "Unlock writing prompts")
                    }
                }
                .font(Fonts.display(14, .bold))
                .lineLimit(3)
                .foregroundStyle(premium.isPremium ? Palette.ink : Palette.inkSofter)
                .lineSpacing(1)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.inkSofter)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(loc: "Choose a prompt"))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Footer CTA — pinned at the bottom, floats above the keyboard
    private var footer: some View {
        PrimaryButton(title: "Unlock my morning",
                      enabled: !journalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            journalFocused = false
            finish()
        }
    }

    // MARK: Step 0 — journal (the prompt lives in the top bar now — see topBarTitleView — so it
    // never competes with the writing area for space). Mood is set via the tappable icon on the
    // date row, which opens `MoodPickerSheet` — no longer a separate blocking step.
    private var journalBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageDateRow(date: Date(), mood: mood) {
                Haptics.select()
                showMoodSheet = true
            }

            RichTextEditor(attributedText: $richText,
                           selectedRange: $selectedRange, placeholder: "Start writing…",
                           keyboardAllowed: !editorSheetPresented)
                .focused($journalFocused)
                // See the matching comment in EntryEditorView.swift — `.frame(minHeight:)`
                // defaults to center alignment, which is why the empty placeholder sat mid-box
                // instead of at its top until typed content grew past the floor.
                .frame(minHeight: 220, alignment: .top)
                .padding(.top, 16)
        }

    }

    // MARK: Finish
    private func finish() {
        let thumbnail = richText.firstPhotoThumbnail()
        let entry = store.saveRitual(mood: mood ?? 0, journal: journalText,
                                     richContent: richText.rtfdData(), tags: tags,
                                     themeID: theme.rawValue, thumbnail: thumbnail)
        // Without this, History's page-curl reader keeps whatever `PageHost` it already cached for
        // today (see `EntryDetailView.swift`'s `PageCurlReader.Coordinator`) — stale content, and a
        // stale layout frame for any image/sticker resized since that page was cached, which shows
        // up as content that's wrong, oversized, or clipped. `EntryEditorView.save()` already posts
        // this for the "edit an old entry" path; the main write flow needs the same call for a
        // same-day re-write to invalidate correctly.
        NotificationCenter.default.post(name: .journalEntryDidUpdate, object: entry.dayKey)
        Haptics.success()
        withAnimation(Motion.gentle) { step = 1 }
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
                IconTileButton(icon: "xmark", size: 38, iconSize: 13) { dismiss() }
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

// MARK: - Celebration (step 1)

private struct CelebrationView: View {
    let mood: Int
    let streak: Int
    let words: Int
    let affirmation: String
    var onStart: () -> Void

    @Environment(\.requestReview) private var requestReview
    @Environment(ScreenTimeManager.self) private var screenTime

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

                Text(loc: screenTime.blockingPresentation.isScheduledNow
                     ? "Your apps are awake" : "You made time for yourself.")
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

                Text("Mood: \(Text(loc: Mood(rawValue: mood)?.label ?? "Sad"))  ·  \(words) words")
                    .font(Fonts.ui(12.5, .bold)).foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 18)

                VStack(spacing: 6) {
                    Eyebrow(text: "Today's affirmation", color: .white.opacity(0.85), tracking: 1.2, size: 11)
                    Affirmations.text(affirmation)
                        .font(Fonts.display(19, .semibold)).foregroundStyle(.white)
                        .multilineTextAlignment(.center).lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 300)
                .padding(.top, 22)
                .popIn(delay: 0.5)

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
