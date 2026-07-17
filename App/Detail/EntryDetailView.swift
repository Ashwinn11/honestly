import SwiftUI

struct EntryDetailView: View {
    let dayKey: String
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedKey: String

    init(dayKey: String) {
        self.dayKey = dayKey
        _selectedKey = State(initialValue: dayKey)
    }

    private var entries: [JournalEntry] { store.entries }

    var body: some View {
        ZStack(alignment: .top) {
            PaperBackground()
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
    }

    private var reader: some View {
        VStack(spacing: 0) {
            readerHeader
                .capWidth(Metrics.maxContentWidth)

            TabView(selection: $selectedKey) {
                ForEach(entries, id: \.dayKey) { entry in
                    JournalReaderPage(entry: entry)
                        .tag(entry.dayKey)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
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

private struct JournalReaderPage: View {
    let entry: JournalEntry

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                // Full-bleed, no card border/shadow — same continuous-page treatment as RitualView,
                // so writing and reading feel like the same physical object.
                JournalPageSurface(lineHeight: 33,
                                   cornerRadius: 0,
                                   showsMargin: false,
                                   showsBinderHoles: false,
                                   bordered: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        PageDateRow(date: entry.date, mood: entry.moodRaw)
                            .padding(.bottom, 20)

                        Text(entry.journal)
                            .font(Fonts.ui(16.5, .semibold))
                            .foregroundStyle(Palette.inkBody)
                            .lineSpacing(11)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer(minLength: 32)

                        pageFooter
                    }
                    .padding(EdgeInsets(top: 22, leading: 22, bottom: 24, trailing: 22))
                    .frame(minHeight: proxy.size.height, alignment: .topLeading)
                }
                .capWidth(Metrics.maxContentWidth)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var pageFooter: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Palette.hairline.opacity(0.7))
                .frame(height: 1)
            Text("morning page")
                .textCase(.uppercase)
                .font(Fonts.ui(10, .heavy))
                .tracking(1.2)
                .foregroundStyle(Palette.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
