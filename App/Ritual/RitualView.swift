import SwiftUI
import UIKit
import StoreKit

struct RitualView: View {
    var onClose: () -> Void
    @Environment(JournalStore.self) private var store
    @Environment(PremiumManager.self) private var premium
    @Environment(AppFlow.self) private var flow
    @Environment(PromptLibrary.self) private var prompts
    @Environment(CoverStore.self) private var covers

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
    // The month's book opens as the page appears — skipped for Reduce Motion and screenshots.
    @State private var showOpening = !UIAccessibility.isReduceMotionEnabled && ScreenshotPreview.screen == nil
    @State private var showBook = false

    private var editorSheetPresented: Bool {
        showFormattingSheet || showTagsSheet || showImagePicker || showDoodleSheet || showStickerSheet || showThemeSheet || showPromptPicker || showMoodSheet || showBook || flow.paywallPresented
    }

    /// This month's book — today's page is written into it.
    private var monthBook: MonthBook { MonthBook.containing(Date(), in: store) }

    /// The month's pages before today's — what "read earlier pages" opens and the opening riffles past.
    private var earlierPages: [JournalEntry] { monthBook.entries.filter { $0.dayKey != store.todayKey } }

    private var journalText: String { richText.plainText }
    var body: some View {
        @Bindable var flow = flow
        Group {
            if step == 1 {
                CelebrationView(book: monthBook,
                                streak: store.streak,
                                onStart: onClose)
            } else {
                let look = covers.look(for: monthBook)
                VStack(spacing: 0) {
                    // The whole screen is one page — no bar above it. The prompt is printed at its
                    // top, then the date; the editor grows to its actual content height (see
                    // `RichTextEditor`) inside the page's own `ScrollView`, the only scrolling region.
                    GeometryReader { geo in
                        bookPage(height: geo.size.height)
                            .capWidth(Metrics.maxContentWidth)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(PageThemeBackground(theme: theme))
                .safeAreaInset(edge: .bottom) {
                    // While the editor has focus, the footer becomes the formatting toolbar instead
                    // of the step CTA — same slot, same pattern as the rest of the ritual's chrome.
                    // The toolbar itself runs edge-to-edge (no horizontal margin) so its scrollable
                    // row gets full width; the CTA button keeps the page's usual side margin.
                    VStack(spacing: 0) {
                        if journalFocused || showFormattingSheet {
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
                                onFormattingClosed: {
                                    showFormattingSheet = false
                                    DispatchQueue.main.async { journalFocused = true }
                                }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            footer.padding(.horizontal, 22)
                        }
                    }
                    .animation(Motion.snappy, value: journalFocused)
                    .padding(.top, 8)
                    .padding(.bottom, 14)
                }
                // The whole screen is the page: its edges run top to bottom, past the toolbar.
                .overlay { BookEdges() }
                // The book opens over the entire screen, edge to edge.
                .overlay {
                    if showOpening {
                        BookOpeningOverlay(look: look, pagesBefore: earlierPages.count) {
                            withAnimation(.easeOut(duration: 0.2)) { showOpening = false }
                        }
                        .ignoresSafeArea()
                        .transition(.opacity)
                    }
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
        // Earlier pages of this month's book, read without leaving today's page.
        .fullScreenCover(isPresented: $showBook) {
            if let latest = earlierPages.last {
                EntryDetailView(dayKey: latest.dayKey, book: MonthBookRoute(entry: latest))
            }
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
    // The day's prompt, printed at the top of the page like a guided journal's question. Tapping it
    // still opens the prompt list.
    private var promptHeading: some View {
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
                .font(Fonts.display(19, .bold))
                .lineLimit(3)
                .foregroundStyle(premium.isPremium ? Palette.ink : Palette.inkSofter)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(loc: "Choose a prompt"))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: The book page — today's page, set inside the month's book
    private func bookPage(height: CGFloat) -> some View {
        // The same margin as the reader, so the text column is exactly as wide in both.
        let inset = Metrics.pageHorizontalInset
        return VStack(alignment: .leading, spacing: 0) {
            // The prompt and the date head the page and stay put; only the writing scrolls beneath.
            // The page's one control is the small close mark beside the prompt.
            HStack(alignment: .top, spacing: 4) {
                promptHeading
                PageCloseMark { onClose() }
                    .padding(.trailing, -12)
            }
            .padding(EdgeInsets(top: 6, leading: inset, bottom: 0, trailing: inset))

            PageDateRow(date: Date(), mood: mood) {
                Haptics.select()
                showMoodSheet = true
            }
            .padding(EdgeInsets(top: 14, leading: inset, bottom: 0, trailing: inset))

            ScrollView {
                journalBody(minHeight: height)
                    .padding(EdgeInsets(top: 16, leading: inset, bottom: 24, trailing: inset))
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(height, 0), alignment: .top)
        // Swipe from the spine to turn back to this month's earlier pages.
        .simultaneousGesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                guard !earlierPages.isEmpty, value.startLocation.x < 48,
                      value.translation.width > 80, abs(value.translation.height) < 70 else { return }
                openEarlierPages()
            }
        )
        // Pull the page down from its top to close it, as with the close mark.
        .closesOnPullDown { onClose() }
    }

    private func openEarlierPages() {
        journalFocused = false
        Haptics.tap()
        showBook = true
    }

    // MARK: Footer CTA — pinned at the bottom, floats above the keyboard
    private var footer: some View {
        PrimaryButton(title: "Unlock my morning",
                      enabled: !journalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            journalFocused = false
            finish()
        }
    }

    // MARK: Step 0 — journal (the prompt is printed at the top of the page — see promptHeading — so it
    // never competes with the writing area for space). Mood is set via the tappable icon on the
    // date row, which opens `MoodPickerSheet` — no longer a separate blocking step.
    private func journalBody(minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            RichTextEditor(attributedText: $richText,
                           selectedRange: $selectedRange, placeholder: "Start writing…",
                           keyboardAllowed: !editorSheetPresented, ruled: true)
                .focused($journalFocused)
                // See the matching comment in EntryEditorView.swift — `.frame(minHeight:)`
                // defaults to center alignment, which is why the empty placeholder sat mid-box
                // instead of at its top until typed content grew past the floor. The floor fills
                // the page, so its rules run to the bottom like a notebook's.
                .frame(minHeight: max(220, minHeight - 110), alignment: .top)
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
    let book: MonthBook
    let streak: Int
    var onStart: () -> Void

    @Environment(\.requestReview) private var requestReview
    @Environment(ScreenTimeManager.self) private var screenTime

    var body: some View {
        ZStack {
            Palette.celebrationGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                // The streak at the top; the book closing is the moment.
                StreakBadge(streak: streak)
                    .padding(.top, 12)
                    .popIn(delay: 0.2)

                VStack(spacing: 0) {
                    // Today's page goes into the month's book, and the book closes over it.
                    ClosingBookView(book: book, width: 128)
                        .frame(height: 200)

                    Text(loc: screenTime.blockingPresentation.isScheduledNow
                         ? "Your apps are awake" : "You made time for yourself.")
                        .font(Fonts.display(34, .heavy)).foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: Color(hex: "78280A").opacity(0.3), radius: 14, y: 2)
                        .padding(.top, 12)
                    Text("Page \(book.entries.count) of \(HDate.monthName(book.firstOfMonth))")
                        .font(Fonts.ui(15, .heavy)).foregroundStyle(.white.opacity(0.92))
                        .padding(.top, 8)
                        .popIn(delay: 0.25)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                CreamButton(title: "Start my day") { onStart() }
                    .frame(maxWidth: 300)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .capWidth(Metrics.maxContentWidth)   // centered column; gradient stays full-bleed
        }
        .task {
            try? await Task.sleep(for: .seconds(1.2))
            ReviewPrompt.maybeAsk(streak: streak, requestReview)
        }
    }

}

/// The streak as a medal rather than a line: a flame in a coral seal, the count rolling up from
/// yesterday's, and the last seven mornings as beads — today's lighting last.
private struct StreakBadge: View {
    let streak: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Int
    @State private var todayLit = false
    @State private var flare = 0

    init(streak: Int) {
        self.streak = streak
        _shown = State(initialValue: max(streak - 1, 0))
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Palette.amber)
                Circle().strokeBorder(Palette.ink, lineWidth: 2)
                Circle().strokeBorder(Palette.cream.opacity(0.55), lineWidth: 1.5).padding(5)
                Image(systemName: "flame.fill")
                    .font(.system(size: DesignScale.s(21), weight: .bold))
                    .foregroundStyle(Palette.cream)
                    .symbolEffect(.bounce, value: flare)
            }
            .frame(width: DesignScale.s(50), height: DesignScale.s(50))

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: "\(shown)")
                        .font(Fonts.display(30, .heavy))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(shown)))
                    Text("day streak").font(Fonts.ui(14, .heavy))
                }
                week
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(.vertical, 12).padding(.leading, 12).padding(.trailing, 22)
        .background(Palette.cream, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2))
        .tactile(5, cornerRadius: 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(streak) ") + Text("day streak"))
        .task {
            guard !reduceMotion else { shown = streak; todayLit = true; return }
            try? await Task.sleep(for: .seconds(0.75))
            withAnimation(Motion.pop) { shown = streak; todayLit = true }
            flare += 1
            Haptics.success()
        }
    }

    /// The last seven mornings, oldest first; the streak's days are filled.
    private var week: some View {
        let run = min(streak, 7)
        return HStack(spacing: 5) {
            ForEach(0..<7, id: \.self) { i in
                let isToday = i == 6
                let filled = i >= 7 - run && (!isToday || todayLit)
                Circle()
                    .fill(filled ? Palette.amber : Palette.ink.opacity(0.08))
                    .overlay(Circle().strokeBorder(Palette.ink.opacity(filled ? 1 : 0.25), lineWidth: 1.5))
                    .frame(width: DesignScale.s(13), height: DesignScale.s(13))
                    .scaleEffect(isToday && todayLit ? 1.15 : 1)
            }
        }
    }
}

