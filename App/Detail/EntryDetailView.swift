import SwiftUI

struct EntryDetailView: View {
    let dayKey: String
    /// Set when opened as a month book: the reader then turns only that month's pages, oldest
    /// first, behind a Contents page — like a real book. Nil keeps the all-pages reader, newest first.
    var book: MonthBookRoute? = nil
    @Environment(JournalStore.self) private var store
    @Environment(PremiumManager.self) private var premium
    @Environment(AppFlow.self) private var flow
    @Environment(CoverStore.self) private var covers
    @Environment(\.dismiss) private var dismiss
    @State private var selectedKey: String
    @State private var showEditor = false
    @State private var showGrid: Bool
    /// False for one jump: a page picked from the grid appears in place instead of curling over
    /// whatever page happened to sit under the grid.
    @State private var curlJumps = true
    @State private var showOpening: Bool

    init(dayKey: String, book: MonthBookRoute? = nil) {
        self.dayKey = dayKey
        self.book = book
        _selectedKey = State(initialValue: dayKey)
        // A book opened from its cover shows all its pages first; one opened at a page shows that page.
        _showGrid = State(initialValue: book != nil && dayKey == MonthBookRoute.contentsKey)
        _showOpening = State(initialValue: (book?.riffle ?? false) && !UIAccessibility.isReduceMotionEnabled)
    }

    private var entries: [JournalEntry] {
        guard let book else { return store.entries }
        return store.entries(inYear: book.year, month: book.month).reversed()
    }

    /// Every page the reader can turn to, in order: the Contents page first in a book.
    private var pageKeys: [String] {
        (book != nil ? [MonthBookRoute.contentsKey] : []) + entries.map(\.dayKey)
    }

    /// Free accounts can read the current month's book; every other page is Premium.
    private var canRead: Bool {
        if premium.isPremium { return true }
        guard let book else { return false }
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        return now.year == book.year && now.month == book.month
    }

    private var hasPages: Bool {
        store.entry(for: dayKey) != nil || (book != nil && dayKey == MonthBookRoute.contentsKey && !entries.isEmpty)
    }

    // The reader header (back/edit buttons) used to sit over a fixed `PaperBackground()` while
    // the page below it already switched to the entry's theme — a visible seam right where the
    // two met. This tracks the same `selectedKey` the page curl uses, so the header and the page
    // share one background and turn together.
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
        .onChange(of: selectedKey) { _, _ in
            Haptics.select()
            curlJumps = true
        }
        .fullScreenCover(isPresented: $showEditor) {
            if premium.isPremium, let entry = store.entry(for: selectedKey) {
                EntryEditorView(entry: entry)
            }
        }
    }

    private var reader: some View {
        VStack(spacing: 0) {
            readerHeader
                .capWidth(Metrics.maxContentWidth)

            ZStack {
                PageCurlReader(entries: entries,
                               contents: book.map { (year: $0.year, month: $0.month) },
                               selectedKey: $selectedKey,
                               curlJumps: curlJumps)
                if showGrid {
                    pagesGrid.transition(.opacity)
                }
                if showOpening, let book {
                    let month = MonthBook.containing(book.firstOfMonth, in: store)
                    BookOpeningOverlay(look: covers.look(for: month), month: book.firstOfMonth,
                                       pagesBefore: entries.firstIndex { $0.dayKey == dayKey } ?? 0) {
                        withAnimation(.easeOut(duration: 0.2)) { showOpening = false }
                    }
                    .transition(.opacity)
                }
            }
        }
        .background(alignment: .topTrailing) {
            SoftGlow(color: Palette.sunDisc, opacity: 0.14, size: 240)
                .offset(x: 74, y: -74)
        }
        .ignoresSafeArea(.container, edges: .top)
        // The whole screen is the page, as when writing: its edges run top to bottom, header
        // included. The grid of all pages isn't a page, so it goes without.
        .overlay { if !showGrid { BookEdges() } }
    }

    // Back, and — in a book — a jump to its Contents page. The date lives on the page itself
    // (PageDateRow), same as the writing screen, so this chrome doesn't need to repeat it.
    private var readerHeader: some View {
        HStack(spacing: 12) {
            IconTileButton(icon: "chevron.backward", size: 38, iconSize: 15) { dismiss() }
            Spacer(minLength: 0)
            if book != nil && (selectedKey != MonthBookRoute.contentsKey || showGrid) {
                IconTileButton(icon: "calendar", size: 38, iconSize: 15) {
                    withAnimation(Motion.snappy) { showGrid = false }
                    selectedKey = MonthBookRoute.contentsKey
                }
                .accessibilityLabel(Text("Contents"))
            }
            if book != nil && !showGrid {
                IconTileButton(icon: "square.grid.2x2", size: 38, iconSize: 15) {
                    Haptics.select()
                    withAnimation(Motion.snappy) { showGrid = true }
                }
                .accessibilityLabel(Text("See all pages"))
            }
            if store.entry(for: selectedKey) != nil && !showGrid {
                IconTileButton(icon: "pencil", size: 38, iconSize: 15) {
                    // Reading this month is free; editing a page stays Premium.
                    if premium.isPremium { showEditor = true } else { flow.showPaywall() }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 8)
    }

    // MARK: All pages — the whole month at a glance; tap one to turn straight to it
    private var pagesGrid: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
                ForEach(entries, id: \.dayKey) { entry in
                    Button {
                        curlJumps = false
                        selectedKey = entry.dayKey
                        withAnimation(Motion.snappy) { showGrid = false }
                    } label: {
                        MiniPage(entry: entry)
                    }
                    .buttonStyle(PressableStyle())
                    .contextMenu {
                        Button(role: .destructive) { delete(entry) } label: {
                            Label("Delete page", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(EdgeInsets(top: 12, leading: 20, bottom: 30, trailing: 20))
            .capWidth(Metrics.maxContentWidth)
        }
        .scrollIndicators(.hidden)
        .background(PaperBackground())
    }

    private func delete(_ entry: JournalEntry) {
        if selectedKey == entry.dayKey { selectedKey = MonthBookRoute.contentsKey }
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
    /// The book's month when reading a month book — adds its Contents page in front.
    var contents: (year: Int, month: Int)? = nil
    @Binding var selectedKey: String
    /// Whether a jump made from outside the reader curls; false lands on the page in place.
    var curlJumps = true

    var keys: [String] { (contents != nil ? [MonthBookRoute.contentsKey] : []) + entries.map(\.dayKey) }

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
        // A jump from Contents, the page grid or the header curls like turning straight to a page.
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
            hosts.removeValue(forKey: MonthBookRoute.contentsKey)    // its mood faces may have changed
        }

        func page(for key: String) -> PageHost? {
            if let cached = hosts[key] { return cached }
            let fresh: PageHost
            if key == MonthBookRoute.contentsKey, let contents = parent.contents {
                fresh = PageHost(key: key, color: PageTheme.paper.baseUIColor, content: AnyView(
                    BookContentsPage(year: contents.year, month: contents.month,
                                     entries: parent.entries,
                                     onPick: { [weak self] picked in self?.parent.selectedKey = picked })))
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
                .padding(EdgeInsets(top: 22, leading: Metrics.pageHorizontalInset,
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
            RichContentView(attributedText: attributed, ruled: true)
        } else {
            Text(entry.journal)
                .font(Fonts.ui(16.5, .semibold))
                .foregroundStyle(Palette.inkBody)
                .lineSpacing(11)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

}

