import SwiftUI

/// History — all pages grouped by month with a mood filter row. Matches `Honestly.dc.html`
/// lines 421–451.
struct HistoryView: View {
    @Environment(JournalStore.self) private var store
    @State private var filter: Int? = nil          // nil = All

    private var filtered: [JournalEntry] {
        store.entries.filter { filter == nil || $0.moodRaw == filter }
    }

    /// Entries grouped into (label, entries) by month, newest first.
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

    var body: some View {
        ScreenScaffold {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your pages").font(Fonts.display(30, .bold)).foregroundStyle(Palette.ink)
                Text("\(store.totalMornings) mornings and counting.")
                    .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSoft).padding(.top, 5)

                filterChips.padding(.top, 16)

                if filtered.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(groups.enumerated()), id: \.element.label) { gi, group in
                        Text(group.label).font(Fonts.display(18, .bold)).foregroundStyle(Color(hex: "A0917C"))
                            .padding(.top, 18).padding(.bottom, 9)
                        ForEach(group.items, id: \.dayKey) { e in
                            NavigationLink(value: e.dayKey) {
                                EntryRow(entry: e) {
                                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Palette.hairline)
                                }
                            }
                            .buttonStyle(PressableStyle(scale: 0.98))
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation(Motion.snappy) { store.delete(e) }
                                } label: { Label("Delete page", systemImage: "trash") }
                            }
                            .padding(.bottom, 10)
                        }
                    }
                }
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button { toggle(nil) } label: {
                    Text("All").font(Fonts.ui(13, .heavy))
                        .foregroundStyle(filter == nil ? Palette.paper : Palette.inkSoft)
                        .padding(.horizontal, 14).frame(height: 40)
                        .background(filter == nil ? Palette.ink : .white,
                                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .shadow(color: Color(hex: "78501E").opacity(0.07), radius: 6, y: 4)
                }
                .buttonStyle(PressableStyle())
                ForEach(0..<5, id: \.self) { i in
                    Button { toggle(i) } label: {
                        MoodFace(mood: i, size: 26)
                            .frame(width: 40, height: 40)
                            .background(filter == i ? Palette.mood(i) : .white,
                                        in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .shadow(color: Color(hex: "78501E").opacity(0.07), radius: 6, y: 4)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var emptyState: some View {
        Text("No pages with this mood yet.")
            .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSofter)
            .frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    private func toggle(_ value: Int?) {
        Haptics.select()
        withAnimation(Motion.snappy) { filter = (filter == value) ? nil : value }
    }
}

