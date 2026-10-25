import SwiftUI

/// Topic choices are shared by onboarding and Manage affirmations. An empty selection means all
/// topics.
struct AffirmationTopicPicker: View {
    @Environment(AffirmationList.self) private var list
    @Environment(PremiumManager.self) private var premium
    @Binding var selection: [String]
    var onSelection: (() -> Void)? = nil
    private var topics: [String] {
        list.availableLibrary.map(\.title) + (premium.isPremium && !list.savedCustom.isEmpty ? ["Your own"] : [])
    }

    var body: some View {
        VStack(spacing: 0) {
            topicRow("All topics", selected: selection.isEmpty) {
                onSelection?()
                selection = []
            }
            Rectangle().fill(Palette.ink.opacity(0.06)).frame(height: 1)
            ForEach(Array(topics.enumerated()), id: \.element) { index, topic in
                topicRow(topic, selected: selection.contains(topic)) {
                    onSelection?()
                    if selection.isEmpty { selection = [topic] }
                    else if selection.contains(topic) { selection.removeAll { $0 == topic } }
                    else { selection.append(topic) }
                }
                if index < topics.count - 1 {
                    Rectangle().fill(Palette.ink.opacity(0.06)).frame(height: 1)
                }
            }
        }
    }

    private func topicRow(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        let displayTitle = Affirmations.topicDisplayTitle(title)
        return Button(action: action) {
            HStack(spacing: 10) {
                Text(loc: displayTitle).font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.ink)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.amberDeep)
                } else {
                    Circle().strokeBorder(Palette.outlineSoft, lineWidth: 1.4).frame(width: 19, height: 19)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
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
            LibraryHeader(title: "Manage affirmations", onBack: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    LibrarySectionTitle(title: "Your own")
                    if premium.isPremium {
                        LibraryWriteRow(placeholder: "Write your own…", addLabel: "Add", draft: $draft,
                                        resetToken: inputResetToken, onAdd: addDraft)
                        ForEach(custom, id: \.self) { line in managedRow(line) }
                    } else {
                        Button { flow.showPaywall() } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill").foregroundStyle(Palette.inkSofter)
                                Text(loc: "Write your own with Premium")
                                    .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSofter)
                                Spacer()
                            }
                            .padding(14).frame(minHeight: 48)
                            .background(Palette.cream, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.outlineSoft, lineWidth: 1.2))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        LibrarySectionTitle(title: "Affirmation topics")
                        Text(loc: "These topics shape the affirmations you see across Honestly.")
                            .font(Fonts.ui(13, .medium)).foregroundStyle(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 10)
                    topicCard { AffirmationTopicPicker(selection: $selectedTopics) }
                }
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
        .padding(20)
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

    private func topicCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 16)
            .background(Palette.cream, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.outlineSoft, lineWidth: 1.3))
    }

    private func managedRow(_ line: String) -> some View {
        HStack(spacing: 12) {
            SunMark(size: 26, muted: true).accessibilityHidden(true)
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
        .background(Palette.cream, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.outlineSoft, lineWidth: 1.2))
    }

    private func addDraft() {
        guard premium.isPremium else { flow.showPaywall(); return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, list.saveCustom(text) else { Haptics.rigid(); return }
        draft = ""
        inputResetToken &+= 1
        Haptics.success()
    }
}
