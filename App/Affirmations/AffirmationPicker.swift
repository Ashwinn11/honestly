import SwiftUI

/// Topic choices are shared by onboarding and Manage affirmations, two to a row. An empty selection
/// means all topics. Both screens can collapse longer lists behind the same "Show more" control.
struct AffirmationTopicPicker: View {
    @Environment(AffirmationList.self) private var list
    @Environment(PremiumManager.self) private var premium
    @Binding var selection: [String]
    var onSelection: (() -> Void)? = nil
    var collapsedCount: Int? = nil
    @State private var expanded = false

    private var topics: [String] {
        list.availableLibrary.map(\.title) + (premium.allows(.ownAffirmations) && !list.savedCustom.isEmpty ? ["Your own"] : [])
    }

    private var canCollapse: Bool {
        guard let collapsedCount else { return false }
        return topics.count > collapsedCount
    }

    /// Collapsed lists still open up when a chosen topic sits past the cut, so a pick never hides.
    private var showsAll: Bool {
        guard canCollapse, let collapsedCount, !expanded else { return true }
        return selection.contains { !topics.prefix(collapsedCount).contains($0) }
    }

    private var visibleTopics: [String] {
        showsAll ? topics : Array(topics.prefix(collapsedCount ?? topics.count))
    }

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(spacing: 10) {
            topicCell("All topics", selected: selection.isEmpty) {
                onSelection?()
                selection = []
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(visibleTopics, id: \.self) { topic in
                    topicCell(topic, selected: selection.contains(topic)) {
                        onSelection?()
                        if selection.isEmpty { selection = [topic] }
                        else if selection.contains(topic) { selection.removeAll { $0 == topic } }
                        else { selection.append(topic) }
                    }
                }
            }
            if canCollapse && (expanded || !showsAll) {
                Button {
                    Haptics.select()
                    withAnimation(Motion.gentle) { expanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Text(loc: expanded ? "Show less" : "Show more")
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .font(Fonts.ui(14, .bold))
                    .foregroundStyle(Palette.amberDeep)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func topicCell(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        ChoiceRow(title: Affirmations.topicDisplayTitle(title), selected: selected, lineLimit: 2, action: action)
    }
}

/// Create custom affirmations and choose the topics used throughout the app.
struct AffirmationsScreen: View {
    @Environment(AffirmationList.self) private var list
    @Environment(PremiumManager.self) private var premium
    @Environment(AppFlow.self) private var flow
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var inputResetToken = 0
    @State private var selectedTopics: [String] = []
    @State private var pendingDelete: String?

    private var custom: [String] { list.savedCustom }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScreenHeader(Text(loc: "Manage affirmations"), back: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    LibrarySectionTitle(title: "Your own")
                    if premium.allows(.ownAffirmations) {
                        LibraryWriteRow(placeholder: "Write your own…", addLabel: "Add", draft: $draft,
                                        resetToken: inputResetToken, onAdd: addDraft)
                        ForEach(custom, id: \.self) { line in managedRow(line) }
                    } else {
                        PremiumLockedRow(title: "Write your own with Premium") { flow.showPaywall() }
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        LibrarySectionTitle(title: "Affirmation topics")
                        Text(loc: "These topics shape the affirmations you see across Honestly.")
                            .font(Fonts.ui(13, .medium)).foregroundStyle(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 10)
                    AffirmationTopicPicker(selection: $selectedTopics, collapsedCount: 6)

                    AffirmationWidgetCustomizationSection()
                        .padding(.top, 10)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .capWidth(Metrics.maxContentWidth)
        .background(PaperBackground())
        .toolbar(.hidden, for: .tabBar)
        .onAppear { selectedTopics = list.selectedTopics }
        .onChange(of: selectedTopics) { _, topics in list.setSelectedTopics(topics) }
        .onChange(of: list.selectedTopics) { _, topics in
            if selectedTopics != topics { selectedTopics = topics }
        }
        .confirmationDialog("Delete affirmation?", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
        ), titleVisibility: .visible, presenting: pendingDelete) { line in
            Button("Delete", role: .destructive) { list.delete(line); pendingDelete = nil }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { _ in
            Text(loc: "This removes the affirmation from your library, widgets and reminders.")
        }
    }

    private func managedRow(_ line: String) -> some View {
        HStack(spacing: 12) {
            QuoteMark(size: 17)
            Affirmations.text(line)
                .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                Button("Delete", role: .destructive) { pendingDelete = line }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.inkSofter).frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text(loc: "Manage affirmation"))
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, 12)
        .outlinedSurface(radius: Radius.control)
    }

    private func addDraft() {
        guard premium.allows(.ownAffirmations) else { flow.showPaywall(); return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, list.saveCustom(text) else { Haptics.rigid(); return }
        draft = ""
        inputResetToken &+= 1
        Haptics.success()
    }
}
