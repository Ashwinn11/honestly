import SwiftUI

struct EntryEditorView: View {
    let entry: JournalEntry
    @Environment(JournalStore.self) private var store
    @Environment(AppFlow.self) private var flow
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

    private var editorSheetPresented: Bool {
        showFormattingSheet || showTagsSheet || showImagePicker || showDoodleSheet || showStickerSheet || showThemeSheet || flow.paywallPresented
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
    }

    var body: some View {
        VStack(spacing: 0) {
            // The same header as writing and reading, with ✓ to keep the changes beside the ✕.
            PageHeader(date: entry.createdAt, mood: entry.moodRaw) {
                PageCloseButton { dismiss() }
                IconTileButton(icon: "checkmark", size: 38, iconSize: 14) { save() }
                    .accessibilityLabel(Text("Save"))
            }
            .padding(EdgeInsets(top: 4, leading: Metrics.pageHorizontalInset,
                                bottom: 0, trailing: Metrics.pageHorizontalInset - 3))
            .capWidth(Metrics.maxContentWidth)

            // One scroll, not two: `RichTextEditor` grows to its actual content height (like
            // `RichContentView`, the read-only reader). This outer ScrollView is the only scrolling region.
            ScrollView {
                JournalPageSurface(cornerRadius: 0, showsBinderHoles: false, bordered: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        if !entry.prompt.isEmpty {
                            PageAnsweredPrompt(text: entry.prompt)
                        }

                        RichTextEditor(attributedText: $richText,
                                       selectedRange: $selectedRange, placeholder: "Start writing…",
                           keyboardAllowed: !editorSheetPresented)
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
        .background(PageThemeBackground(theme: theme))
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
                        }
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
        .onChange(of: editorSheetPresented) { _, presented in
            if presented { journalFocused = false }
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
