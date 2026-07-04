import SwiftUI

struct HistoryView: View {
    @Environment(JournalStore.self) private var store
    @State private var filter: Int? = nil          // nil = All

    private var filtered: [JournalEntry] {
        store.entries.filter { filter == nil || $0.moodRaw == filter }
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

    var body: some View {
        if filtered.isEmpty {
            emptyLayout
        } else {
            ScreenScaffold {
                VStack(alignment: .leading, spacing: 0) {
                    titleBlock
                    filterChips.padding(.top, 16)
                    list
                }
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your pages").font(Fonts.display(30, .bold)).foregroundStyle(Palette.ink)
            Text("\(store.totalMornings) mornings and counting.")
                .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSoft).padding(.top, 5)
        }
    }

    private var list: some View {
        ForEach(Array(groups.enumerated()), id: \.element.label) { _, group in
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

    // MARK: Filter row — All + five moods, stretched end-to-end across the width
    private var filterChips: some View {
        HStack(spacing: 8) {
            chip(selected: filter == nil, fill: filter == nil ? Palette.ink : .white) { toggle(nil) } label: {
                Text("All").font(Fonts.ui(13, .heavy))
                    .foregroundStyle(filter == nil ? Palette.paper : Palette.inkSoft)
            }
            ForEach(0..<5, id: \.self) { i in
                chip(selected: filter == i, fill: filter == i ? Palette.mood(i) : .white) { toggle(i) } label: {
                    MoodFace(mood: i, size: 26)
                }
            }
        }
    }

    private func chip<L: View>(selected: Bool, fill: Color, action: @escaping () -> Void,
                               @ViewBuilder label: () -> L) -> some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(fill, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .shadow(color: Color(hex: "78501E").opacity(0.07), radius: 6, y: 4)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Empty state — header + filters at top, component centered in the space below
    private var emptyLayout: some View {
        ZStack(alignment: .top) {
            PaperBackground()
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    titleBlock
                    filterChips.padding(.top, 16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .capWidth(Metrics.maxContentWidth)

                Spacer()
                emptyState
                Spacer()
            }
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Palette.amber.opacity(0.10)).frame(width: 104, height: 104)
                SunMark(size: 58, stroke: Palette.amber, fill: Palette.amberLight).floaty(period: 5)
            }
            VStack(spacing: 7) {
                Text(filter == nil ? "No pages yet" : "None with this mood")
                    .font(Fonts.display(21, .bold)).foregroundStyle(Palette.ink)
                Text(filter == nil
                     ? "Write your first morning page —\nit'll gather here."
                     : "Try another mood, or write today's page.")
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
}
