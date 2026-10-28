import SwiftUI

struct LibraryView: View {
    @Environment(JournalStore.self) private var store
    @Environment(PremiumManager.self) private var premium
    @Environment(AppFlow.self) private var flow
    @State private var filter: Int? = nil          // nil = All
    @State private var query = ""
    @State private var coverBook: MonthBook?
    @State private var editing: JournalEntry?
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// Three across on a phone, four on an iPad's wider column.
    private var columnCount: Int { sizeClass == .regular ? 4 : 3 }

    private var isSearching: Bool {
        filter != nil || !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Free accounts read this month's book; every earlier month is Premium.
    private func canOpen(_ book: MonthBook) -> Bool { premium.allows(.fullHistory) || book.isCurrent }

    /// What search and the mood filter look through — every page, or this month's for free accounts.
    private var searchable: [JournalEntry] {
        if premium.allows(.fullHistory) { return store.entries }
        let cal = Calendar.current
        return store.entries.filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
    }

    private var filtered: [JournalEntry] {
        let q = query.trimmingCharacters(in: .whitespaces)
        // Strip a leading "#" so searching "#calm" and "calm" both match the tag
        let tagQuery = q.hasPrefix("#") ? String(q.dropFirst()) : q
        return searchable.filter { entry in
            (filter == nil || entry.moodRaw == filter) &&
            (q.isEmpty ||
             entry.content.localizedCaseInsensitiveContains(q) ||
             entry.tags.contains { $0.localizedCaseInsensitiveContains(tagQuery) })
        }
    }

    private var groups: [(label: String, items: [JournalEntry])] {
        var order: [String] = []
        var map: [String: [JournalEntry]] = [:]
        for e in filtered {
            let label = HDate.monthTitle(e.date)
            if map[label] == nil { order.append(label) }
            map[label, default: []].append(e)
        }
        return order.map { ($0, map[$0]!) }
    }

    // MARK: Books — one per month that has pages, plus this month's even before its first page
    private var books: [MonthBook] {
        let cal = Calendar.current
        let now = cal.dateComponents([.year, .month], from: Date())
        var byMonth = Dictionary(grouping: store.entries) { cal.dateComponents([.year, .month], from: $0.date) }
        if byMonth[now] == nil { byMonth[now] = [] }
        return byMonth
            .map { comps, items in
                MonthBook(year: comps.year ?? 0, month: comps.month ?? 0,
                          entries: items.sorted { $0.date < $1.date },
                          isCurrent: comps == now)
            }
            .sorted { ($0.year, $0.month) > ($1.year, $1.month) }
    }

    var body: some View {
        let all = books
        ScreenScaffold {
            VStack(alignment: .leading, spacing: 0) {
                titleBlock
                searchField.padding(.top, 16)
                filterChips.padding(.top, 12)
                if isSearching {
                    if filtered.isEmpty { emptyState.padding(.top, 80) } else { results }
                } else {
                    shelf(all)
                }
            }
        }
        .sheet(item: $coverBook) { book in
            CoverEditorSheet(book: book)
        }
        .fullScreenCover(item: $editing) { entry in
            EntryEditorView(entry: entry)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your pages").font(Fonts.display(30, .bold)).foregroundStyle(Palette.ink)
                .fixedSize()
            Text("\(store.totalMornings) mornings, and counting.")
                .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSoft).padding(.top, 12)
        }
    }

    // MARK: Shelf
    @ViewBuilder private func shelf(_ all: [MonthBook]) -> some View {
        if let current = all.first(where: \.isCurrent) {
            featured(current).padding(.top, 26)
        }
        let earlier = all.filter { !$0.isCurrent }
        let years = Dictionary(grouping: earlier, by: \.year).sorted { $0.key > $1.key }
        ForEach(years, id: \.key) { group in
            yearShelf(year: group.key, books: group.value).padding(.top, 34)
        }
    }

    private func featured(_ book: MonthBook) -> some View {
        HStack(alignment: .bottom, spacing: DesignScale.s(20)) {
            bookButton(book, width: 150)
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "Still writing", color: Palette.amberDeep)
                Text(verbatim: HDate.monthName(book.firstOfMonth))
                    .font(Fonts.display(24, .bold)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                pageCount(book.entries.count)
                    .font(Fonts.ui(13, .semibold)).foregroundStyle(Palette.inkSoft)
                featuredAction(book).padding(.top, 8)
            }
            .padding(.bottom, 6)
        }
    }

    @ViewBuilder private func featuredAction(_ book: MonthBook) -> some View {
        if !store.ritualDoneToday {
            Button { flow.startRitual() } label: { actionLabel("Write today's page") }
                .buttonStyle(TactileButtonStyle(fill: AnyShapeStyle(Palette.onAmber),
                                                cornerRadius: DesignScale.s(Radius.control), ledge: 4, bordered: true))
        } else if canOpen(book), let route = book.route {
            NavigationLink(value: route) { actionLabel("Open book") }
                .buttonStyle(TactileButtonStyle(fill: AnyShapeStyle(Palette.onAmber),
                                                cornerRadius: DesignScale.s(Radius.control), ledge: 4, bordered: true))
        }
    }

    private func actionLabel(_ key: String) -> some View {
        Text(loc: key).font(Fonts.ui(13.5, .heavy)).foregroundStyle(Palette.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
    }

    private func yearShelf(year: Int, books: [MonthBook]) -> some View {
        let total = books.reduce(0) { $0 + $1.entries.count }
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: String(year)).font(Fonts.display(18, .bold)).foregroundStyle(Palette.ink)
                Spacer()
                pageCount(total).font(Fonts.ui(12, .bold)).foregroundStyle(Palette.inkSoft)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .bottom), count: columnCount),
                      spacing: 26) {
                ForEach(books) { book in
                    VStack(spacing: 8) {
                        bookButton(book, width: 92)
                        pageCount(book.entries.count)
                            .font(Fonts.ui(11, .bold)).foregroundStyle(Palette.inkSoft)
                    }
                }
            }
            .padding(.top, 14)
        }
    }

    @ViewBuilder private func bookButton(_ book: MonthBook, width: CGFloat) -> some View {
        let cover = MonthBookCover(book: book, width: width, locked: !canOpen(book))
        if canOpen(book), let route = book.route {
            NavigationLink(value: route) { cover }
                .buttonStyle(PressableStyle(scale: 0.97))
                .contextMenu { coverMenu(book) }
        } else {
            Button {
                if book.entries.isEmpty {
                    if !store.ritualDoneToday { flow.startRitual() }
                } else {
                    flow.showPaywall()
                }
            } label: { cover }
            .buttonStyle(PressableStyle(scale: 0.97))
            .contextMenu { coverMenu(book) }
        }
    }

    /// Long-press a book to change its cover — Premium for earlier months, like reading them.
    private func coverMenu(_ book: MonthBook) -> some View {
        Button {
            if canOpen(book) { coverBook = book } else { flow.showPaywall() }
        } label: {
            Label { Text("Customize cover") } icon: { Image(systemName: "paintpalette") }
        }
    }

    private func pageCount(_ n: Int) -> Text {
        n == 1 ? Text("1 page") : Text("\(n) pages")
    }

    // MARK: Search results — the same page cards as a book's grid, by month; each opens in its book
    private var results: some View {
        let term = query.trimmingCharacters(in: .whitespaces)
        let highlight = term.hasPrefix("#") ? String(term.dropFirst()) : term
        return ForEach(Array(groups.enumerated()), id: \.element.label) { _, group in
            Text(group.label).font(Fonts.display(18, .bold)).foregroundStyle(Palette.sectionLabel)
                .padding(.top, 18).padding(.bottom, 10)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount), spacing: 14) {
                ForEach(group.items, id: \.dayKey) { e in
                    NavigationLink(value: MonthBookRoute(entry: e)) {
                        MiniPage(entry: e, highlight: highlight)
                    }
                    .buttonStyle(PressableStyle())
                    .contextMenu {
                        Button {
                            // Editing a page is Premium, like everywhere else.
                            afterMenuCloses {
                                flow.requiring(.editPages, premium: premium) { editing = e }
                            }
                        } label: { Label("Edit page", systemImage: "pencil") }
                        Button(role: .destructive) {
                            afterMenuCloses { withAnimation(Motion.snappy) { store.delete(e) } }
                        } label: { Label("Delete page", systemImage: "trash") }
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.inkSofter)
            TextField(LocalizedStringKey("Search your pages…"), text: $query)
                .font(Fonts.ui(14.5, .semibold)).foregroundStyle(Palette.ink)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14)).foregroundStyle(Palette.inkSofter)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(EdgeInsets(top: 11, leading: 14, bottom: 11, trailing: 14))
        .outlinedSurface(radius: Radius.control)
    }

    // MARK: Filter row — an "All" pill + five mood tiles, spread across the full width
    private var filterChips: some View {
        HStack(spacing: 8) {
            Button { toggle(nil) } label: {
                Text("All").font(Fonts.ui(13, .heavy))
                    .foregroundStyle(filter == nil ? Palette.paper : Palette.ink)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(filter == nil ? Palette.ink : Palette.cream, in: Capsule())
                    .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2))
            }
            .buttonStyle(PressableStyle())

            ForEach(0..<5, id: \.self) { i in
                Button { toggle(i) } label: {
                    MoodFace(mood: i, size: 26)
                        .frame(width: 40, height: 40)
                        .background(filter == i ? Palette.moodSoft(i) : Palette.cream,
                                    in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                            .strokeBorder(filter == i ? Palette.mood(i) : Palette.ink.opacity(0.22),
                                    lineWidth: filter == i ? 2.5 : 2))
                        .frame(maxWidth: .infinity)          // spread evenly across the width
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private var emptyState: some View {
        EmptyState(title: emptyTitle, message: emptyBody)
    }

    private func toggle(_ value: Int?) {
        Haptics.select()
        withAnimation(Motion.snappy) { filter = (filter == value) ? nil : value }
    }

    private var emptyTitle: String {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty { return "No matches" }
        return "None with this mood"
    }
    private var emptyBody: String {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty { return "Try a different word or two." }
        return "Try another mood, or write today's page."
    }
}
