import SwiftUI

struct TagEditorSheet: View {
    @Binding var tags: [String]
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var direction
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    private var suggestions: [String] {
        var seen = Set(tags)
        return store.entries.flatMap(\.tags).filter { seen.insert($0).inserted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScreenHeader(Text(loc: "Tags"), trailing: {
                (Text(tags.count, format: .number) + Text(verbatim: " / ") + Text(TagEditing.maxTags, format: .number))
                    .font(Fonts.ui(13, .semibold)).foregroundStyle(Palette.inkSofter)
                IconTileButton.close { commit(); dismiss() }
            })
            HStack(spacing: 10) {
                TextField(LocalizedStringKey("Add tag"), text: $draft)
                    .font(Fonts.ui(16, .semibold)).foregroundStyle(Palette.ink)
                    .submitLabel(.done).focused($inputFocused)
                    .onSubmit(commit)
                    .disabled(tags.count >= TagEditing.maxTags)
                IconTileButton(icon: "plus", size: 38, iconSize: 14) { commit() }
                    .accessibilityLabel(Text(loc: "Add tag"))
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || tags.count >= TagEditing.maxTags)
            }
            .padding(12)
            .outlinedSurface(radius: Radius.control)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !tags.isEmpty {
                        TagFlowLayout(rightToLeft: direction == .rightToLeft) {
                            ForEach(tags, id: \.self) { tag in
                                TagChip(text: tag) { tags.removeAll { $0 == tag } }
                            }
                        }
                    }
                    if !suggestions.isEmpty && tags.count < TagEditing.maxTags {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(loc: "Recent tags").font(Fonts.ui(12, .bold)).foregroundStyle(Palette.inkSofter)
                            TagFlowLayout(rightToLeft: direction == .rightToLeft) {
                                ForEach(suggestions, id: \.self) { tag in
                                    Button {
                                        var reused = tag
                                        TagEditing.commit(draft: &reused, into: &tags)
                                        Haptics.select()
                                    } label: { TagChip(text: tag).frame(minHeight: 44) }
                                    .buttonStyle(PressableStyle())
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 20)               // inside the scroll, so nothing ends short of the edge
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(EdgeInsets(top: 20, leading: 20, bottom: 0, trailing: 20))
        .sheetBackground()
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.visible)
        .onDisappear { commit() }
    }

    private func commit() {
        TagEditing.commit(draft: &draft, into: &tags)
    }
}
