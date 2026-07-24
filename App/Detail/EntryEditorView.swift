import SwiftUI

struct EntryEditorView: View {
    let entry: JournalEntry
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var richText = NSAttributedString()
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var tags: [String] = []
    @State private var tagDraft = ""
    @State private var theme: PageTheme = .paper
    @FocusState private var journalFocused: Bool

    @State private var showImagePicker = false
    @State private var showDoodleSheet = false
    @State private var showStickerSheet = false
    @State private var showThemeSheet = false

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

    private var wordCount: Int {
        JournalEntry.wordCount(of: richText.plainText)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar.capWidth(Metrics.maxContentWidth)

            // One scroll, not two: `RichTextEditor` grows to its actual content height (like
            // `RichContentView`, the read-only reader) instead of scrolling internally, so tags and
            // word count sit right after wherever the text actually ends, not stretched to the
            // bottom of the screen — this outer `ScrollView` is the page's only scrolling region.
            ScrollView {
                JournalPageSurface(cornerRadius: 0, showsBinderHoles: false, bordered: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        PageDateRow(date: entry.createdAt, mood: entry.moodRaw)
                            .padding(.bottom, 16)

                        RichTextEditor(attributedText: $richText,
                                       selectedRange: $selectedRange, placeholder: "Start writing…")
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
                            .padding(.top, 16)

                        TagEditorRow(tags: $tags, draft: $tagDraft)
                            .padding(.top, 16)

                        if wordCount > 0 {
                            Text("\(wordCount) words — nice")
                                .font(Fonts.ui(12.5, .semibold)).foregroundStyle(Palette.inkSofter)
                                .padding(.top, 10)
                        }
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
                    Spacer().frame(height: 10)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 14)
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

    private var topBar: some View {
        HStack(spacing: 12) {
            IconTileButton(icon: "xmark", size: 38, iconSize: 13) {
                dismiss()
            }
            Text("Edit Entry")
                .font(Fonts.display(19, .bold)).foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
            IconTileButton(icon: "checkmark", size: 38, iconSize: 14) {
                save()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
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
        // Flush any tag that's still sitting in the input, typed but never submitted — tapping
        // this checkmark directly (rather than dismissing the keyboard first) doesn't reliably
        // commit it via TagEditorRow's own focus-loss handler before this reads `tags`.
        TagEditing.commit(draft: &tagDraft, into: &tags)

        let plain = richText.plainText
        let data = richText.rtfdData()
        let thumbnail = richText.firstPhotoThumbnail()

        store.update(entry, journal: plain, richContent: data, tags: tags, themeID: theme.rawValue, thumbnail: thumbnail)
        
        NotificationCenter.default.post(name: .journalEntryDidUpdate, object: entry.dayKey)
        
        Haptics.success()
        dismiss()
    }
}
