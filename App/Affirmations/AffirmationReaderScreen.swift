import SwiftUI

/// A one-at-a-time reader. Topic choices here also drive the Home affirmation, reminders, and widgets.
struct AffirmationReaderScreen: View {
    @Environment(AffirmationList.self) private var list
    @Environment(PremiumManager.self) private var premium
    @Environment(\.dismiss) private var dismiss
    var startingLine: String? = nil
    @State private var lines: [String] = []
    @State private var page = 0
    @State private var filter: AffirmationReaderFilter = .allTopics

    private var current: String? { lines.indices.contains(page) ? lines[page] : nil }
    private var isFavorite: Bool { current.map { list.favorites.contains($0) } ?? false }

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    IconTileButton.back { dismiss() }
                    Text(loc: "Affirmations")
                        .font(Fonts.ui(15, .bold)).foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Menu {
                        filterMenuItem("All topics", value: .allTopics)
                        Divider()
                        ForEach(filterTopics, id: \.self) { topic in
                            filterMenuItem(topic, value: .topic(topic))
                        }
                        Divider()
                        filterMenuItem("Favorites", value: .favorites)
                        filterMenuItem("Recently read", value: .recentlyRead)
                    } label: {
                        IconTile(size: 38, fill: Palette.cream) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: DesignScale.s(15), weight: .bold)).foregroundStyle(Palette.ink)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(Text(loc: "Filter affirmations"))
                    .accessibilityValue(Text(loc: filter.title))
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                if let line = current {
                    TabView(selection: $page) {
                        ForEach(Array(lines.enumerated()), id: \.element) { index, item in
                            GeometryReader { geometry in
                                VStack(spacing: 24) {
                                    QuoteMark(size: 38)
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
                    EmptyState(title: emptyTitle, message: emptyMessage)
                    Spacer()
                }
            }
            .capWidth(Metrics.maxContentWidth)
        }
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            refresh(preserving: startingLine)
        }
        .onChange(of: list.favorites) { _, _ in
            if filter == .favorites { refresh(preserving: current) }
        }
    }

    private func refresh(preserving line: String?) {
        switch filter {
        case .allTopics:
            lines = Affirmations.feedRotation(focusTitles: [], premium: premium.allows(.fullAffirmations))
        case .topic(let title):
            lines = Affirmations.feedRotation(focusTitles: [title], premium: premium.allows(.fullAffirmations))
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
        case .allTopics, .topic: return "No affirmations here"
        case .favorites: return "No favorites yet"
        case .recentlyRead: return "Nothing read yet"
        }
    }

    private var emptyMessage: String {
        switch filter {
        case .allTopics, .topic: return "No affirmations available"
        case .favorites: return "Save affirmations with the heart to find them here."
        case .recentlyRead: return "Affirmations you read will appear here."
        }
    }

    private var filterTopics: [String] {
        list.availableLibrary.map(\.title) + (premium.allows(.ownAffirmations) && !list.savedCustom.isEmpty ? ["Your own"] : [])
    }

    private func filterMenuItem(_ title: String, value: AffirmationReaderFilter) -> some View {
        let displayTitle: String
        if case let .topic(topic) = value {
            displayTitle = Affirmations.topicDisplayTitle(topic)
        } else {
            displayTitle = title
        }
        return Button {
            guard filter != value else { return }
            filter = value
            refresh(preserving: current)
        } label: {
            if filter == value {
                Label { Text(loc: displayTitle) } icon: { Image(systemName: "checkmark") }
            } else {
                Text(loc: displayTitle)
            }
        }
    }

}

private enum AffirmationReaderFilter: Hashable {
    case allTopics
    case topic(String)
    case favorites
    case recentlyRead

    var title: String {
        switch self {
        case .allTopics: return "All topics"
        case .topic(let title): return Affirmations.topicDisplayTitle(title)
        case .favorites: return "Favorites"
        case .recentlyRead: return "Recently read"
        }
    }
}
