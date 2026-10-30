import SwiftUI

struct EntryEditorView: View {
    let entry: JournalEntry
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var richText = NSAttributedString()
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var tags: [String] = []
    @State private var showTagsSheet = false
    @State private var theme: PageTheme = .paper
    @FocusState private var journalFocused: Bool

    @State private var showImagePicker = false
    @State private var showDoodleSheet = false
    @State private var showStickerSheet = false
    @State private var showThemeSheet = false
    @State private var showFormattingSheet = false
    @State private var showPaywall = false

    private var editorSheetPresented: Bool {
        showFormattingSheet || showTagsSheet || showImagePicker || showDoodleSheet || showStickerSheet || showThemeSheet || showPaywall
    }

    init(entry: JournalEntry) {
        self.entry = entry
        _tags = State(initialValue: entry.tags)
        _theme = State(initialValue: PageTheme.from(entry.themeID))
        
        let initialText: NSAttributedString
        if let data = entry.richContent, let attr = NSAttributedString.from(rtfdData: data), attr.length > 0 {
            initialText = attr
        } else {
            initialText = NSAttributedString(string: entry.content, attributes: RichTextEditor.defaultAttributes)
        }
        _richText = State(initialValue: initialText)
        // The caret waits at the end of what's written, ready to carry on.
        _selectedRange = State(initialValue: NSRange(location: initialText.length, length: 0))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Discard the local edits with ✕, or keep them with ✓.
            PageHeader(date: entry.createdAt, mood: entry.moodRaw) {
                HStack(spacing: 6) {
                    IconTileButton.close { dismiss() }
                    IconTileButton.confirm { save() }
                }
            }
            .padding(EdgeInsets(top: 4, leading: Metrics.pageHorizontalInset,
                                bottom: 0, trailing: Metrics.pageHorizontalInset - 3))
            .capWidth(Metrics.maxContentWidth)

            // One scroll, not two: `RichTextEditor` grows to its actual content height (like
            // `RichContentView`, the read-only reader). This outer ScrollView is the only scrolling region.
            ScrollView {
                JournalPageSurface(cornerRadius: 0, showsBinderHoles: false, bordered: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        RichTextEditor(attributedText: $richText,
                                       selectedRange: $selectedRange, placeholder: "Start writing…",
                           keyboardAllowed: !editorSheetPresented,
                           minimumHeight: max(200, UIScreen.main.bounds.height * 0.6))
                            .focused($journalFocused)
                            // `.frame(minHeight:)` defaults to *center* alignment: when the editor
                            // is empty, `sizeThatFits` reports just the placeholder's one-line
                            // height, and without an explicit `.top` here that small view gets
                            // centered inside the enforced 200pt slot instead of pinned to its top
                            // — the placeholder sits mid-box until typed content grows past 200pt
                            // and the "centering" has no slack left, at which point it visibly
                            // snaps up. `alignment: .top` is what a text editor's box should do
                            // regardless of how much (or little) it's holding.
                            .frame(minHeight: 200, alignment: .top)
                    }
                    .padding(EdgeInsets(top: 14, leading: Metrics.pageHorizontalInset,
                                        bottom: 24, trailing: Metrics.pageHorizontalInset))
                }
                .capWidth(Metrics.maxContentWidth)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .pageTheme(theme)
        .safeAreaInset(edge: .bottom) {
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
                            // Wait for the sheet state to propagate so the UITextView is allowed
                            // to become first responder again before restoring SwiftUI focus.
                            DispatchQueue.main.async { journalFocused = true }
                        },
                        // This editor is a cover, so it shows the paywall over itself.
                        onLocked: { showPaywall = true },
                        pageInk: theme.ink
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Spacer().frame(height: 10)
                }
            }
            .animation(Motion.snappy, value: journalFocused)
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
        // Opening a page to edit it is opening it to write: the keyboard comes up straight away.
        .task {
            try? await Task.sleep(for: .milliseconds(350))     // let the cover finish presenting
            journalFocused = true
        }
        .onChange(of: editorSheetPresented) { _, presented in
            if presented { journalFocused = false }
        }
        .paywallCover(isPresented: $showPaywall)
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
    }

    private func insertPickedImage(_ image: UIImage) {
        let oldLength = richText.length
        let updated = RichTextFormatting.insertImage(image, at: selectedRange.location, in: richText)
        richText = updated
        // Same reasoning as the sticker sheet above — land the caret after the inserted block
        // (its trailing newline), not at the stale pre-insert location.
        selectedRange = NSRange(location: selectedRange.location + (updated.length - oldLength), length: 0)
    }

    private func save() {
        let plain = richText.plainText
        let data = richText.rtfdData()
        let thumbnail = richText.firstPhotoThumbnail()

        store.update(entry, journal: plain, richContent: data, tags: tags, themeID: theme.rawValue, thumbnail: thumbnail)
        
        NotificationCenter.default.post(name: .journalEntryDidUpdate, object: entry.dayKey)
        
        Haptics.success()
        dismiss()
    }
}
