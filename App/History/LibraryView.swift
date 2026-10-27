import SwiftUI

/// Which month book to open, and the page to open it at. Pushed on the tab's NavigationStack;
/// `MainTabView` turns it into a month-scoped `EntryDetailView`.
struct MonthBookRoute: Hashable {
    /// Opens a book at its grid of all pages; also the key of the title page in front of its first
    /// page, where curling back to the grid lands.
    static let gridKey = "book-grid"

    let year: Int
    let month: Int
    let startKey: String
    /// Open with the cover swinging open and the pages riffling to `startKey`, as writing does.
    var riffle = false

    init(year: Int, month: Int, startKey: String, riffle: Bool = false) {
        self.year = year
        self.month = month
        self.startKey = startKey
        self.riffle = riffle
    }

    /// The book an entry lives in, opened at that entry.
    init(entry: JournalEntry, riffle: Bool = false) {
        let c = Calendar.current.dateComponents([.year, .month], from: entry.date)
        self.init(year: c.year ?? 0, month: c.month ?? 0, startKey: entry.dayKey, riffle: riffle)
    }

    var firstOfMonth: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }
}

/// One month of pages, shown as a book on the Library shelf.
struct MonthBook: Identifiable {
    let year: Int
    let month: Int
    let entries: [JournalEntry]          // oldest first — the order the pages turn
    let isCurrent: Bool

    var id: String { "\(year)-\(month)" }

    var firstOfMonth: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    /// The month's most-used page theme (ties go to the most recent page) — what an auto cover
    /// is dressed in until covers become customizable.
    var theme: PageTheme {
        var counts: [PageTheme: Int] = [:]
        for e in entries { counts[PageTheme.from(e.themeID), default: 0] += 1 }
        return entries.reversed()
            .max { counts[PageTheme.from($0.themeID), default: 0] < counts[PageTheme.from($1.themeID), default: 0] }
            .map { PageTheme.from($0.themeID) } ?? .paper
    }

    /// The newest photo written into the month, if any — it becomes the cover.
    var coverPhoto: UIImage? {
        entries.reversed().lazy.compactMap { $0.thumbnail.flatMap(UIImage.init(data:)) }.first
    }

    /// Opens on the grid of all pages; nil while the month has no pages yet.
    var route: MonthBookRoute? {
        entries.isEmpty ? nil : MonthBookRoute(year: year, month: month, startKey: MonthBookRoute.gridKey)
    }
}

struct LibraryView: View {
    @Environment(JournalStore.self) private var store
    @Environment(PremiumManager.self) private var premium
    @Environment(AppFlow.self) private var flow
    @State private var filter: Int? = nil          // nil = All
    @State private var query = ""
    @State private var coverBook: MonthBook?

    private var isSearching: Bool {
        filter != nil || !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Free accounts read this month's book; every earlier month is Premium.
    private func canOpen(_ book: MonthBook) -> Bool { premium.isPremium || book.isCurrent }

    /// What search and the mood filter look through — every page, or this month's for free accounts.
    private var searchable: [JournalEntry] {
        if premium.isPremium { return store.entries }
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
        if !premium.isPremium && all.contains(where: { !$0.isCurrent }) {
            PremiumUnlockCard(title: "Unlock your full history",
                              subtitle: "Every morning you've written, always here to revisit.",
                              action: { flow.showPaywall() })
                .padding(.top, 28)
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
                                                cornerRadius: DesignScale.s(14), ledge: 4, bordered: true))
        } else if canOpen(book), let route = book.route {
            NavigationLink(value: route) { actionLabel("Open book") }
                .buttonStyle(TactileButtonStyle(fill: AnyShapeStyle(Palette.onAmber),
                                                cornerRadius: DesignScale.s(14), ledge: 4, bordered: true))
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
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .bottom), count: 3),
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
            Text(group.label).font(Fonts.display(18, .bold)).foregroundStyle(Color(hex: "A0917C"))
                .padding(.top, 18).padding(.bottom, 10)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
                ForEach(group.items, id: \.dayKey) { e in
                    NavigationLink(value: MonthBookRoute(entry: e)) {
                        MiniPage(entry: e, highlight: highlight)
                    }
                    .buttonStyle(PressableStyle())
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation(Motion.snappy) { store.delete(e) }
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
        .background(Palette.cream, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.outlineSoft, lineWidth: 1.5))
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
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(filter == i ? Palette.mood(i) : Palette.ink.opacity(0.22),
                                    lineWidth: filter == i ? 2.5 : 2))
                        .frame(maxWidth: .infinity)          // spread evenly across the width
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                SoftGlow(color: Palette.sunDisc, opacity: 0.2, size: 180)
                SunMark(size: 58).floaty(period: 5)
            }
            VStack(spacing: 7) {
                Text(loc: emptyTitle)
                    .font(Fonts.display(21, .bold)).foregroundStyle(Palette.ink)
                Text(loc: emptyBody)
                    .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSofter)
                    .multilineTextAlignment(.center).lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
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

// MARK: - The book

/// A month as a closed book: cover (the month's newest photo, else its most-used theme), the
/// month's moods along the bottom, and a block of page edges that thickens as pages are written.
/// The book still being written carries a ribbon.
struct MonthBookCover: View {
    let book: MonthBook
    var width: CGFloat = 92
    var locked = false
    /// Shown instead of the saved cover — the cover editor's live preview.
    var lookOverride: CoverLook? = nil
    @Environment(CoverStore.self) private var covers

    init(book: MonthBook, width: CGFloat = 92, locked: Bool = false, lookOverride: CoverLook? = nil) {
        self.book = book
        self.width = width
        self.locked = locked
        self.lookOverride = lookOverride
    }

    var body: some View {
        let w = DesignScale.s(width)
        let h = w * 1.42
        let edge = w * (0.03 + 0.003 * CGFloat(min(book.entries.count, 31)))   // 3% → ~12% of the width
        let look = lookOverride ?? covers.look(for: book)
        let photo = look.photo
        let ink = look.ink
        let coverShape = UnevenRoundedRectangle(topLeadingRadius: w * 0.03, bottomLeadingRadius: w * 0.03,
                                                bottomTrailingRadius: w * 0.09, topTrailingRadius: w * 0.09,
                                                style: .continuous)

        ZStack(alignment: .topLeading) {
            PageEdges()
                .frame(width: edge + w * 0.08, height: h - w * 0.07)
                .offset(x: w - w * 0.08, y: w * 0.035)

            ZStack(alignment: .bottomLeading) {
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                        .frame(width: w, height: h).clipped()
                    LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                } else {
                    look.color
                    CoverDots(color: look.ink.opacity(0.09), spacing: w * 0.11)
                }
                Rectangle().fill(.black.opacity(0.16))                     // the spine's fold
                    .frame(width: w * 0.07)
                    .frame(maxHeight: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: w * 0.025) {
                    Text(verbatim: String(book.year))
                        .font(Fonts.ui(width * 0.075, .heavy)).tracking(width * 0.015)
                    Text(verbatim: HDate.monthName(book.firstOfMonth))
                        .font(Fonts.display(width * 0.165, .heavy))
                        .lineLimit(1).minimumScaleFactor(0.55)
                    if !book.entries.isEmpty && width >= 80 {     // too small to read on a mini book
                        HStack(spacing: w * 0.015) {
                            ForEach(Array(book.entries.suffix(7).enumerated()), id: \.offset) { _, e in
                                MoodFace(mood: e.moodRaw, size: w * 0.085)
                            }
                        }
                        .padding(.top, w * 0.03)
                    }
                }
                .foregroundStyle(ink)
                .padding(.leading, w * 0.14).padding(.trailing, w * 0.06).padding(.bottom, w * 0.1)
            }
            .frame(width: w, height: h)
            .clipShape(coverShape)
            .overlay(coverShape.strokeBorder(Palette.ink, lineWidth: 2))

            if book.isCurrent {
                RibbonShape()
                    .fill(Palette.amber)
                    .overlay(RibbonShape().stroke(Palette.ink, lineWidth: 2))
                    .frame(width: w * 0.1, height: h * 0.3)
                    .offset(x: w * 0.72, y: -w * 0.04)
            }

            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: w * 0.11, weight: .bold)).foregroundStyle(Palette.amberDeep)
                    .frame(width: w * 0.26, height: w * 0.26)
                    .background(Palette.iconTile, in: Circle())
                    .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2))
                    .offset(x: w * 0.66, y: w * 0.08)
            }
        }
        .frame(width: w + edge, height: h, alignment: .topLeading)
        .shadow(color: Color(hex: "78501E").opacity(0.22), radius: w * 0.08, x: 0, y: w * 0.07)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: HDate.monthTitle(book.firstOfMonth)))
        .accessibilityHint(locked ? Text("Unlock Premium") : Text(verbatim: ""))
    }
}

/// The stack of page edges showing past the cover's open side.
private struct PageEdges: View {
    var body: some View {
        let shape = UnevenRoundedRectangle(bottomTrailingRadius: 5, topTrailingRadius: 5, style: .continuous)
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Palette.cream))
            var x: CGFloat = 2
            while x < size.width {
                ctx.fill(Path(CGRect(x: x, y: 0, width: 0.75, height: size.height)),
                         with: .color(Color(hex: "D8CBB6")))
                x += 2.5
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.ink, lineWidth: 2))
    }
}

/// A quiet dot texture so theme covers read as cloth, not flat UI.
private struct CoverDots: View {
    let color: Color
    let spacing: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let r: CGFloat = max(1, spacing * 0.12)
            var y = spacing / 2
            var row = 0
            while y < size.height {
                var x = spacing / 2 + (row.isMultiple(of: 2) ? 0 : spacing / 2)
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(color))
                    x += spacing
                }
                y += spacing
                row += 1
            }
        }
    }
}

/// A bookmark ribbon with a V-notched tail.
private struct RibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.width * 0.7))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

extension PageTheme {
    /// Book-cover colour for a month whose pages mostly use this theme — a deeper take on the
    /// page wash so covers read as covers on the shelf, plus the ink that stays legible on it.
    var cover: (color: Color, ink: Color) {
        switch self {
        case .paper:        return (Color(hex: "E9DCC3"), Palette.ink)
        case .grid:         return (Color(hex: "DAD5C5"), Palette.ink)
        case .dots:         return (Color(hex: "E8D5B5"), Palette.ink)
        case .linen:        return (Color(hex: "CFBE9F"), Palette.ink)
        case .ledger:       return (Color(hex: "BCC6D2"), Palette.ink)
        case .meadow:       return (Color(hex: "AFC895"), Palette.ink)
        case .mushroomWood: return (Color(hex: "C9A27E"), Palette.ink)
        case .library:      return (Color(hex: "7E4F33"), Color(hex: "FFF7EA"))
        case .inkGold:      return (Color(hex: "2F2A24"), Color(hex: "E9CB7A"))
        case .midnight:     return (Color(hex: "3F4589"), Color(hex: "F3F0FF"))
        case .stargazer:    return (Color(hex: "2F3654"), Color(hex: "EEF0FA"))
        case .tide:         return (Color(hex: "8DBCCB"), Palette.ink)
        case .seaGlass:     return (Color(hex: "A3CFBD"), Palette.ink)
        case .ballet:       return (Color(hex: "EDBAC5"), Palette.ink)
        case .cherry:       return (Color(hex: "B0423B"), Color(hex: "FFF3F1"))
        case .sunshine:     return (Color(hex: "F2C35B"), Palette.ink)
        case .bubblegum:    return (Color(hex: "EFA8D1"), Palette.ink)
        }
    }
}
