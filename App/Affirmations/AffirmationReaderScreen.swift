import SwiftUI

/// A one-at-a-time reader. Topic choices here also drive the Home affirmation, reminders, and widgets.
struct AffirmationReaderScreen: View {
    @Environment(AffirmationList.self) private var list
    @Environment(PremiumManager.self) private var premium
    @Environment(\.dismiss) private var dismiss
    var startingLine: String? = nil
    @State private var lines: [String] = []
    @State private var page = 0
    @State private var showingTopics = false
    @State private var readerTopics: [String] = []
    @State private var topicDraft: [String] = []
    @State private var filter: AffirmationReaderFilter = .topics
    @State private var filterDraft: AffirmationReaderFilter = .topics

    private var current: String? { lines.indices.contains(page) ? lines[page] : nil }
    private var isFavorite: Bool { current.map { list.favorites.contains($0) } ?? false }

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    IconTileButton(icon: "chevron.backward", size: 38, iconSize: 15) { dismiss() }
                    Text(loc: "Affirmations")
                        .font(Fonts.ui(15, .bold)).foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        topicDraft = readerTopics
                        filterDraft = filter
                        showingTopics = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                            .frame(width: 38, height: 38)
                            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.ink, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(loc: "Filter affirmations"))
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                if let line = current {
                    TabView(selection: $page) {
                        ForEach(Array(lines.enumerated()), id: \.element) { index, item in
                            GeometryReader { geometry in
                                VStack(spacing: 24) {
                                    SunMark(size: 56).accessibilityHidden(true)
                                    Affirmations.text(item)
                                        .font(Fonts.display(30, .bold)).foregroundStyle(Palette.ink)
                                        .multilineTextAlignment(.center).lineSpacing(6)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: DesignScale.s(350))
                                }
                                .padding(.horizontal, 28).padding(.vertical, 30)
                                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onChange(of: page) { _, newPage in
                        guard lines.indices.contains(newPage) else { return }
                        list.recordRead(lines[newPage])
                    }

                    HStack(spacing: 24) {
                        IconTileButton(icon: "chevron.backward", size: 38, iconSize: 15) { move(by: -1) }
                            .disabled(page == 0).opacity(page == 0 ? 0.35 : 1)
                            .accessibilityLabel(Text(loc: "Previous affirmation"))
                        Text("\(page + 1) / \(lines.count)")
                            .font(Fonts.ui(13, .semibold)).foregroundStyle(Palette.inkSofter)
                            .monospacedDigit().frame(minWidth: 54)
                        Button { list.toggleFavorite(line) } label: {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(isFavorite ? Palette.amberDeep : Palette.inkSoft)
                                .frame(width: 42, height: 42)
                                .background(Palette.cream, in: Circle())
                                .overlay(Circle().strokeBorder(Palette.outlineSoft, lineWidth: 1.2))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(loc: isFavorite ? "Remove from Favorites" : "Add to Favorites"))
                        .accessibilityAddTraits(isFavorite ? .isSelected : [])
                        IconTileButton(icon: "chevron.forward", size: 38, iconSize: 15) { move(by: 1) }
                            .disabled(page >= lines.count - 1).opacity(page >= lines.count - 1 ? 0.35 : 1)
                            .accessibilityLabel(Text(loc: "Next affirmation"))
                    }
                    .padding(.bottom, 10)

                } else {
                    Spacer()
                    SunMark(size: 60).padding(.bottom, 24)
                    Text(loc: emptyTitle)
                        .font(Fonts.display(25, .bold)).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                    Text(loc: emptyMessage)
                        .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center).padding(.top, 8)
                        .padding(.horizontal, 30)
                    Spacer()
                }
            }
            .capWidth(Metrics.maxContentWidth)
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showingTopics) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    LibraryHeader(title: "Filter affirmations", onBack: { showingTopics = false })
                    Spacer()
                    Button("Done") {
                        if filterDraft == .topics { readerTopics = topicDraft }
                        filter = filterDraft
                        showingTopics = false
                        refresh(preserving: current)
                    }
                    .font(Fonts.ui(14, .bold)).foregroundStyle(Palette.amberDeep)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        LibrarySectionTitle(title: "Your collection")
                        VStack(spacing: 0) {
                            filterRow("Favorites", selected: filterDraft == .favorites) { filterDraft = .favorites }
                            Rectangle().fill(Palette.ink.opacity(0.06)).frame(height: 1)
                            filterRow("Recently read", selected: filterDraft == .recentlyRead) { filterDraft = .recentlyRead }
                        }
                        .padding(.horizontal, 16)
                        .background(Palette.cream, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.outlineSoft, lineWidth: 1.2))

                        LibrarySectionTitle(title: "Topics")
                        AffirmationTopicPicker(selection: $topicDraft) { filterDraft = .topics }
                            .padding(.horizontal, 16)
                            .background(Palette.cream, in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.outlineSoft, lineWidth: 1.2))
                    }
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .background(PaperBackground())
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            readerTopics = list.selectedTopics
            refresh(preserving: startingLine)
        }
        .onChange(of: list.favorites) { _, _ in
            if filter == .favorites { refresh(preserving: current) }
        }
    }

    private func refresh(preserving line: String?) {
        switch filter {
        case .topics:
            lines = Affirmations.feedRotation(focusTitles: readerTopics, premium: premium.isPremium)
        case .favorites:
            lines = list.favorites
        case .recentlyRead:
            lines = list.readingHistory
        }
        page = line.flatMap { lines.firstIndex(of: $0) } ?? 0
        if let current { list.recordRead(current) }
    }

    private func move(by offset: Int) {
        let target = page + offset
        guard lines.indices.contains(target) else { return }
        Haptics.select()
        page = target
    }

    private var emptyTitle: String {
        switch filter {
        case .topics: return "No affirmations here"
        case .favorites: return "No favorites yet"
        case .recentlyRead: return "Nothing read yet"
        }
    }

    private var emptyMessage: String {
        switch filter {
        case .topics: return "Choose topics to personalize your feed."
        case .favorites: return "Save affirmations with the heart to find them here."
        case .recentlyRead: return "Affirmations you read will appear here."
        }
    }

    private func filterRow(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(loc: title).font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.ink)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.amberDeep)
                } else {
                    Circle().strokeBorder(Palette.outlineSoft, lineWidth: 1.4).frame(width: 19, height: 19)
                }
            }
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

}

private enum AffirmationReaderFilter: Equatable { case topics, favorites, recentlyRead }
