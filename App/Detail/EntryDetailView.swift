import SwiftUI

struct EntryDetailView: View {
    let dayKey: String
    /// Set when opened as a month book: the reader then turns only that month's pages, oldest
    /// first, like a real book. Nil keeps the all-pages reader, newest first.
    var book: MonthBookRoute? = nil
    @Environment(JournalStore.self) private var store
    @Environment(PremiumManager.self) private var premium
    @Environment(AppFlow.self) private var flow
    @Environment(\.dismiss) private var dismiss
    @State private var selectedKey: String
    @State private var showEditor = false
    @State private var editKey: String?             // the page the editor opens on
    /// The book's grid of all pages (or its calendar). Not a page: it has the only header.
    @State private var showGrid: Bool
    @State private var gridMode: GridMode = .pages
    /// False for one jump: a page picked from the grid appears in place instead of curling over
    /// whatever page happened to sit under the grid.
    @State private var curlJumps = true
    @State private var showPageActions = false
    @State private var confirmDelete = false
    /// Opened from a book's cover: closing a page goes back to the grid, not out of the book.
    private let startsInGrid: Bool

    private enum GridMode: Hashable { case pages, calendar }

    init(dayKey: String, book: MonthBookRoute? = nil) {
        self.dayKey = dayKey
        self.book = book
        let fromCover = book != nil && dayKey == MonthBookRoute.gridKey
        startsInGrid = fromCover
        _selectedKey = State(initialValue: dayKey)
        // A book opened from its cover shows all its pages first; one opened at a page shows that page.
        _showGrid = State(initialValue: fromCover)
    }

    private var entries: [JournalEntry] {
        guard let book else { return store.entries }
        return store.entries(inYear: book.year, month: book.month).reversed()
    }

    /// Every page the reader can turn to, in order. A book has a title page in front of its first
    /// page: curling back onto it is curling back to the grid.
    private var pageKeys: [String] {
        (book != nil ? [MonthBookRoute.gridKey] : []) + entries.map(\.dayKey)
    }

    /// Free accounts can read the current month's book; every other page is Premium.
    private var canRead: Bool {
        if premium.isPremium { return true }
        guard let book else { return false }
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        return now.year == book.year && now.month == book.month
    }

    private var hasPages: Bool {
        store.entry(for: dayKey) != nil || (book != nil && dayKey == MonthBookRoute.gridKey && !entries.isEmpty)
    }

    // Behind the pages (it shows at the corners during an over-curl), tracking the page in view so
    // nothing seams against it.
    @ViewBuilder private var background: some View {
        if let entry = store.entry(for: selectedKey) {
            PageThemeBackground(theme: PageTheme.from(entry.themeID))
        } else {
            PaperBackground()
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            background
            if !canRead {
                PremiumUnlockCard(title: "Unlock your full history",
                                  subtitle: "Every morning you've written, always here to revisit.",
                                  action: { flow.showPaywall() })
                    .padding(.top, 80)
            } else if hasPages {
                reader
            } else {
                missing
            }
        }
        .onAppear {
            if !pageKeys.contains(selectedKey) {
                selectedKey = pageKeys.contains(dayKey) ? dayKey : (pageKeys.first ?? dayKey)
            }
        }
        .onChange(of: premium.isPremium) { _, active in
            if !active { showEditor = false }
        }
        .onChange(of: selectedKey) { _, key in
            Haptics.select()
            curlJumps = true
            // Curled back past the first page, onto the title page: that's the grid.
            if key == MonthBookRoute.gridKey && !showGrid {
                withAnimation(Motion.snappy) { showGrid = true }
            }
        }
        .fullScreenCover(isPresented: $showEditor) {
            if premium.isPremium, let entry = store.entry(for: editKey ?? selectedKey) {
                EntryEditorView(entry: entry)
            }
        }
        .confirmationDialog(Text(verbatim: pageTitle), isPresented: $showPageActions, titleVisibility: .visible) {
            Button { edit(selectedKey) } label: { Text("Edit page") }
            Button(role: .destructive) { confirmDelete = true } label: { Text("Delete page") }
            Button(role: .cancel) {} label: { Text("Cancel") }
        }
        .alert(Text("Delete this page?"), isPresented: $confirmDelete) {
            Button(role: .destructive) { deleteSelected() } label: { Text("Delete page") }
            Button(role: .cancel) {} label: { Text("Cancel") }
        } message: {
            Text("This can't be undone.")
        }
    }

    // MARK: The page — the whole screen, nothing on it but a small close mark
    private var reader: some View {
        ZStack(alignment: .top) {
            PageCurlReader(entries: entries,
                           titlePage: book.map { $0.firstOfMonth },
                           selectedKey: $selectedKey,
                           curlJumps: curlJumps)
                .ignoresSafeArea()
                // Long-press a page for what you can do with it — nothing sits on the page itself.
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                        guard store.entry(for: selectedKey) != nil else { return }
                        Haptics.tap()
                        showPageActions = true
                    }
                )
                .closesOnPullDown { closePage() }

            BookEdges()

            PageCloseMark { closePage() }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 14)

            if showGrid {
                gridScreen.transition(.opacity)
            }
        }
    }

    /// Closing a page returns to where it was opened from: the book's grid, or out of the book.
    private func closePage() {
        if startsInGrid {
            withAnimation(Motion.snappy) { showGrid = true }
        } else {
            dismiss()
        }
    }

    private var pageTitle: String {
        store.entry(for: selectedKey).map { HDate.dayMonthYear($0.date) } ?? ""
    }

    private func edit(_ key: String) {
        // Reading this month is free; editing a page stays Premium.
        editKey = key
        if premium.isPremium { showEditor = true } else { flow.showPaywall() }
    }

    // MARK: The grid — all the month's pages, or its calendar. Not a page, so it has a header.
    private var gridScreen: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconTileButton(icon: "chevron.backward", size: 38, iconSize: 15) { dismiss() }
                Text(verbatim: book.map { HDate.monthName($0.firstOfMonth) } ?? "")
                    .font(Fonts.display(21, .bold)).foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                gridModeSwitch
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .capWidth(Metrics.maxContentWidth)

            ScrollView {
                Group {
                    if gridMode == .pages {
                        pagesGrid
                    } else if let book {
                        BookCalendar(year: book.year, month: book.month, entries: entries,
                                     onPick: { open($0) })
                    }
                }
                .padding(EdgeInsets(top: 8, leading: 20, bottom: 30, trailing: 20))
                .capWidth(Metrics.maxContentWidth)
            }
            .scrollIndicators(.hidden)
        }
        .background(PaperBackground().ignoresSafeArea())
    }

    // Pages | Calendar — rectangular, the active side coral, as elsewhere in the app.
    private var gridModeSwitch: some View {
        HStack(spacing: 0) {
            modeButton(.pages, icon: "square.grid.2x2", label: Text("See all pages"))
            Rectangle().fill(Palette.ink).frame(width: 2)
            modeButton(.calendar, icon: "calendar", label: Text("Calendar"))
        }
        .frame(height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2))
    }

    private func modeButton(_ mode: GridMode, icon: String, label: Text) -> some View {
        Button {
            Haptics.select()
            withAnimation(Motion.snappy) { gridMode = mode }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                .frame(width: 44, height: 40)
                .background(gridMode == mode ? Palette.amber : Palette.cream)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(gridMode == mode ? .isSelected : [])
    }

    private var pagesGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
            ForEach(entries, id: \.dayKey) { entry in
                Button { open(entry.dayKey) } label: { MiniPage(entry: entry) }
                    .buttonStyle(PressableStyle())
                    .contextMenu {
                        Button { edit(entry.dayKey) } label: {
                            Label("Edit page", systemImage: "pencil")
                        }
                        Button(role: .destructive) { delete(entry) } label: {
                            Label("Delete page", systemImage: "trash")
                        }
                    }
            }
        }
    }

    /// Open a page from the grid: it's already in place under the grid as the grid fades away.
    private func open(_ key: String) {
        curlJumps = false
        selectedKey = key
        withAnimation(Motion.snappy) { showGrid = false }
    }

    private func deleteSelected() {
        guard let entry = store.entry(for: selectedKey) else { return }
        delete(entry)
        // Back to the book's grid while it still has pages; otherwise out of the book.
        if book != nil && !entries.isEmpty {
            withAnimation(Motion.snappy) { showGrid = true }
        } else {
            dismiss()
        }
    }

    private func delete(_ entry: JournalEntry) {
        if selectedKey == entry.dayKey { selectedKey = MonthBookRoute.gridKey }
        withAnimation(Motion.snappy) { store.delete(entry) }
    }

    private var missing: some View {
        VStack(spacing: 14) {
            IconTileButton(icon: "chevron.backward", size: 38, iconSize: 15) { dismiss() }
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            Text("This page has drifted off.").font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.inkSofter)
            Spacer()
        }
        .padding(.horizontal, 22).padding(.top, 56)
    }
}

/// The real paper page-turn (UIKit's `.pageCurl`, the old-iBooks curl) — SwiftUI's
/// `TabView(.page)` can only slide, so the reader bridges to `UIPageViewController` here.
/// Lives in this file because it hosts the private `JournalReaderPage`.
private struct PageCurlReader: UIViewControllerRepresentable {
    let entries: [JournalEntry]
    /// The book's month when reading a month book — adds its title page in front of the first
    /// page, which is where curling back to the grid lands.
    var titlePage: Date? = nil
    @Binding var selectedKey: String
    /// Whether a jump made from outside the reader curls; false lands on the page in place.
    var curlJumps = true

    var keys: [String] { (titlePage != nil ? [MonthBookRoute.gridKey] : []) + entries.map(\.dayKey) }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = UIPageViewController(transitionStyle: .pageCurl, navigationOrientation: .horizontal)
        pvc.dataSource = context.coordinator
        pvc.delegate = context.coordinator
        // The container stays clear so PaperBackground peeks through at the corners during an
        // over-curl; the pages themselves must be opaque (see PageHost).
        pvc.view.backgroundColor = .clear
        if let page = context.coordinator.page(for: selectedKey) {
            pvc.setViewControllers([page], direction: .forward, animated: false)
        }
        return pvc
    }

    func updateUIViewController(_ pvc: UIPageViewController, context: Context) {
        context.coordinator.parent = self

        // Keep the visible page's paper in step with its theme after an edit changes it.
        if let host = pvc.viewControllers?.first as? PageHost,
           let entry = entries.first(where: { $0.dayKey == host.key }) {
            host.view.backgroundColor = PageTheme.from(entry.themeID).baseUIColor
        }

        // Never touch the page stack mid-turn, and only reset when selection moved externally —
        // the delegate callback lands here too.
        guard !context.coordinator.isTurning else { return }
        let visible = (pvc.viewControllers?.first as? PageHost)?.key
        guard visible != selectedKey, let page = context.coordinator.page(for: selectedKey) else { return }

        let from = keys.firstIndex { $0 == visible } ?? 0
        let to = keys.firstIndex { $0 == selectedKey } ?? 0
        // A jump made from outside the reader curls like turning straight to a page.
        let animated = curlJumps && !UIAccessibility.isReduceMotionEnabled
        if animated { context.coordinator.isTurning = true }
        pvc.setViewControllers([page], direction: to >= from ? .forward : .reverse, animated: animated) { _ in
            context.coordinator.isTurning = false
        }
    }

    final class PageHost: UIHostingController<AnyView> {
        let key: String
        init(key: String, color: UIColor, content: AnyView) {
            self.key = key
            // Pages are hosted outside the SwiftUI tree, so the in-app language is re-applied here.
            super.init(rootView: AnyView(content.environment(\.locale, Locale(identifier: SharedState.language))))
            // Must be opaque: the curl deforms a snapshot of this view, and a transparent page
            // renders as nothing but a bent edge — no visible paper to peel.
            view.backgroundColor = color
        }
        @available(*, unavailable) required dynamic init?(coder: NSCoder) { fatalError() }
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PageCurlReader
        // One host per page, reused across data-source calls — pageCurl tracks pages by
        // identity, and handing it a fresh controller for the same page corrupts its
        // internal transition queue.
        private var hosts: [String: PageHost] = [:]
        // True from turn start until the settle animation lands. A swipe that begins during
        // the settle crashes UIKit's curl ("number of view controllers provided (0)…"),
        // so the data source reports no neighbours until the turn is done.
        var isTurning = false

        init(_ parent: PageCurlReader) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(handleEntryUpdate(_:)),
                                                   name: .journalEntryDidUpdate, object: nil)
        }

        @objc private func handleEntryUpdate(_ notification: Notification) {
            guard let dayKey = notification.object as? String else { return }
            hosts.removeValue(forKey: dayKey)
        }

        func page(for key: String) -> PageHost? {
            if let cached = hosts[key] { return cached }
            let fresh: PageHost
            if key == MonthBookRoute.gridKey, let month = parent.titlePage {
                fresh = PageHost(key: key, color: PageTheme.paper.baseUIColor,
                                 content: AnyView(BookTitlePage(month: month, pages: parent.entries.count)))
            } else if let entry = parent.entries.first(where: { $0.dayKey == key }) ?? parent.entries.first {
                if let cached = hosts[entry.dayKey] { return cached }
                fresh = PageHost(key: entry.dayKey, color: PageTheme.from(entry.themeID).baseUIColor,
                                 content: AnyView(JournalReaderPage(entry: entry)))
            } else {
                return nil
            }
            hosts[fresh.key] = fresh
            return fresh
        }

        private func index(of vc: UIViewController) -> Int? {
            guard let key = (vc as? PageHost)?.key else { return nil }
            return parent.keys.firstIndex(of: key)
        }

        func pageViewController(_ pvc: UIPageViewController,
                                viewControllerBefore vc: UIViewController) -> UIViewController? {
            guard !isTurning, let i = index(of: vc), i > 0 else { return nil }
            return page(for: parent.keys[i - 1])
        }

        func pageViewController(_ pvc: UIPageViewController,
                                viewControllerAfter vc: UIViewController) -> UIViewController? {
            let keys = parent.keys
            guard !isTurning, let i = index(of: vc), i < keys.count - 1 else { return nil }
            return page(for: keys[i + 1])
        }

        func pageViewController(_ pvc: UIPageViewController,
                                willTransitionTo pendingViewControllers: [UIViewController]) {
            isTurning = true
        }

        func pageViewController(_ pvc: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            isTurning = false
            guard completed, let key = (pvc.viewControllers?.first as? PageHost)?.key else { return }
            parent.selectedKey = key
        }
    }
}

private struct JournalReaderPage: View {
    let entry: JournalEntry

    var body: some View {
        ScrollView {
            // Full-bleed, no card border/shadow — same continuous-page treatment as RitualView, so
            // writing and reading feel like the same physical object. Sized to its actual content,
            // not forced to fill the screen — see RitualView's body for why (forcing it left a
            // large dead gap below short entries instead of the barely-visible seam it avoided).
            JournalPageSurface(cornerRadius: 0,
                               showsBinderHoles: false,
                               bordered: false) {
                VStack(alignment: .leading, spacing: 0) {
                    PageDateRow(date: entry.date, mood: entry.moodRaw)
                        .padding(.bottom, 20)

                    journalContent

                    if !entry.tags.isEmpty {
                        TagRow(tags: entry.tags)
                            .padding(.top, 18)
                    }


                }
                // The same margin as the writing page, so the text column matches it exactly.
                .padding(EdgeInsets(top: 48, leading: Metrics.pageHorizontalInset,
                                    bottom: 24, trailing: Metrics.pageHorizontalInset))
            }
            .capWidth(Metrics.maxContentWidth)
        }
        .scrollIndicators(.hidden)
        .background(PageThemeBackground(theme: PageTheme.from(entry.themeID)))
    }

    // Rich (formatted text + inline images) for entries written after this feature shipped;
    // plain text fallback for every entry written before it — `richContent` is nil there.
    @ViewBuilder private var journalContent: some View {
        if let data = entry.richContent, let attributed = NSAttributedString.from(rtfdData: data),
           attributed.length > 0 {
            RichContentView(attributedText: attributed)
        } else {
            Text(entry.journal)
                .font(Fonts.ui(16.5, .semibold))
                .foregroundStyle(Palette.inkBody)
                .lineSpacing(11)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

}


/// The quiet page in front of a book's first page — the month's name, as on a title page. It's
/// only ever seen mid-curl: landing on it opens the grid.
private struct BookTitlePage: View {
    let month: Date
    let pages: Int

    var body: some View {
        VStack(spacing: 10) {
            Text(verbatim: String(Calendar.current.component(.year, from: month)))
                .font(Fonts.ui(13, .heavy)).tracking(3).foregroundStyle(Palette.inkSoft)
            Text(verbatim: HDate.monthName(month))
                .font(Fonts.display(40, .heavy)).foregroundStyle(Palette.ink)
            (pages == 1 ? Text("1 page") : Text("\(pages) pages"))
                .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PageThemeBackground(theme: .paper))
    }
}
