import SwiftUI

struct EntryDetailView: View {
    let dayKey: String
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedKey: String
    @State private var showEditor = false

    init(dayKey: String) {
        self.dayKey = dayKey
        _selectedKey = State(initialValue: dayKey)
    }

    private var entries: [JournalEntry] { store.entries }

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
            if store.entry(for: dayKey) != nil {
                reader
            } else {
                missing
            }
        }
        .onAppear {
            if store.entry(for: selectedKey) == nil {
                selectedKey = dayKey
            }
        }
        .onChange(of: selectedKey) { _, _ in Haptics.select() }
        .fullScreenCover(isPresented: $showEditor) {
            if let entry = store.entry(for: selectedKey) {
                EntryEditorView(entry: entry)
            }
        }
    }

    private var reader: some View {
        VStack(spacing: 0) {
            readerHeader
                .capWidth(Metrics.maxContentWidth)

            PageCurlReader(entries: entries, selectedKey: $selectedKey)
        }
        .background(alignment: .topTrailing) {
            SoftGlow(color: Palette.sunDisc, opacity: 0.14, size: 240)
                .offset(x: 74, y: -74)
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    // Just the close icon — no share button, no "N of M" pill. The date now lives on the page
    // itself (PageDateRow), same as the writing screen, so this chrome doesn't need to repeat it.
    private var readerHeader: some View {
        HStack(spacing: 12) {
            IconTileButton(icon: "chevron.left", size: 38, iconSize: 15) { dismiss() }
            Spacer(minLength: 0)
            if store.entry(for: selectedKey) != nil {
                IconTileButton(icon: "pencil", size: 38, iconSize: 15) {
                    showEditor = true
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 8)
    }

    private var missing: some View {
        VStack(spacing: 14) {
            IconTileButton(icon: "chevron.left", size: 38, iconSize: 15) { dismiss() }
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
    @Binding var selectedKey: String

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
        
        // Sync currently visible page background color
        if let host = pvc.viewControllers?.first as? PageHost,
           let entry = entries.first(where: { $0.dayKey == host.dayKey }) {
            let theme = PageTheme.from(entry.themeID)
            host.view.backgroundColor = theme.baseUIColor
        }

        // Never touch the page stack mid-turn, and only reset when selection moved externally —
        // the delegate callback lands here too.
        guard !context.coordinator.isTurning else { return }
        let visible = (pvc.viewControllers?.first as? PageHost)?.dayKey
        guard visible != selectedKey, let page = context.coordinator.page(for: selectedKey) else { return }
        
        let theme = PageTheme.from(entries.first(where: { $0.dayKey == selectedKey })?.themeID)
        page.view.backgroundColor = theme.baseUIColor
        
        let from = entries.firstIndex { $0.dayKey == visible } ?? 0
        let to = entries.firstIndex { $0.dayKey == selectedKey } ?? 0
        pvc.setViewControllers([page], direction: to >= from ? .forward : .reverse, animated: false)
    }

    final class PageHost: UIHostingController<JournalReaderPage> {
        let dayKey: String
        init(entry: JournalEntry) {
            dayKey = entry.dayKey
            super.init(rootView: JournalReaderPage(entry: entry))
            // Must be opaque: the curl deforms a snapshot of this view, and a transparent page
            // renders as nothing but a bent edge — no visible paper to peel.
            let theme = PageTheme.from(entry.themeID)
            view.backgroundColor = theme.baseUIColor
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
        private(set) var isTurning = false

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

        private func host(for entry: JournalEntry) -> PageHost {
            if let cached = hosts[entry.dayKey] { return cached }
            let fresh = PageHost(entry: entry)
            hosts[entry.dayKey] = fresh
            return fresh
        }

        func page(for dayKey: String) -> PageHost? {
            (parent.entries.first { $0.dayKey == dayKey } ?? parent.entries.first)
                .map { host(for: $0) }
        }

        private func index(of vc: UIViewController) -> Int? {
            guard let key = (vc as? PageHost)?.dayKey else { return nil }
            return parent.entries.firstIndex { $0.dayKey == key }
        }

        func pageViewController(_ pvc: UIPageViewController,
                                viewControllerBefore vc: UIViewController) -> UIViewController? {
            guard !isTurning, let i = index(of: vc), i > 0 else { return nil }
            return host(for: parent.entries[i - 1])
        }

        func pageViewController(_ pvc: UIPageViewController,
                                viewControllerAfter vc: UIViewController) -> UIViewController? {
            guard !isTurning, let i = index(of: vc), i < parent.entries.count - 1 else { return nil }
            return host(for: parent.entries[i + 1])
        }

        func pageViewController(_ pvc: UIPageViewController,
                                willTransitionTo pendingViewControllers: [UIViewController]) {
            isTurning = true
        }

        func pageViewController(_ pvc: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            isTurning = false
            guard completed, let key = (pvc.viewControllers?.first as? PageHost)?.dayKey else { return }
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
                .padding(EdgeInsets(top: 22, leading: 22, bottom: 24, trailing: 22))
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
