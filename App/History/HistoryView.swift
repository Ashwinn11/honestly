import SwiftUI

struct HistoryView: View {
    @Environment(JournalStore.self) private var store
    @Environment(PremiumManager.self) private var premium
    @Environment(AppFlow.self) private var flow
    @State private var filter: Int? = nil          // nil = All
    @State private var query = ""

    private var filtered: [JournalEntry] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return store.entries.filter { entry in
            (filter == nil || entry.moodRaw == filter) &&
            (q.isEmpty || entry.content.localizedCaseInsensitiveContains(q))
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

    var body: some View {
        ScreenScaffold {
            VStack(alignment: .leading, spacing: 0) {
                titleBlock
                searchField.padding(.top, 16)
                filterChips.padding(.top, 12)
                if !premium.isPremium {
                    lockedState.padding(.top, 60)
                } else if filtered.isEmpty {
                    emptyState.padding(.top, 80)
                } else {
                    list
                }
            }
        }
    }

    private var lockedState: some View {
        PremiumUnlockCard(title: "Unlock your full history",
                           subtitle: "Every morning you've written, always here to revisit.",
                           action: { flow.showPaywall() })
            .frame(maxWidth: .infinity)
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
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.outlineSoft, lineWidth: 1.5))
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your pages").font(Fonts.display(30, .bold)).foregroundStyle(Palette.ink)
                .fixedSize()
                .underlineSquiggle(Palette.sunDisc, weight: 4, height: 9)
            Text("\(store.totalMornings) mornings, and counting.")
                .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSoft).padding(.top, 12)
        }
    }

    private var list: some View {
        ForEach(Array(groups.enumerated()), id: \.element.label) { _, group in
            Text(group.label).font(Fonts.display(18, .bold)).foregroundStyle(Color(hex: "A0917C"))
                .padding(.top, 18).padding(.bottom, 9)
            ForEach(group.items, id: \.dayKey) { e in
                NavigationLink(value: e.dayKey) {
                    EntryRow(entry: e) { EntryScore(count: e.affirmationCount) }
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

    // MARK: Filter row — an "All" pill + five mood tiles, spread across the full width
    private var filterChips: some View {
        HStack(spacing: 8) {
            Button { toggle(nil) } label: {
                Text("All").font(Fonts.ui(13, .heavy))
                    .foregroundStyle(filter == nil ? Palette.paper : Palette.ink)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(filter == nil ? Palette.ink : Palette.cream, in: Capsule())
                    .overlay(Capsule().stroke(Palette.ink, lineWidth: 2))
            }
            .buttonStyle(PressableStyle())

            ForEach(0..<5, id: \.self) { i in
                Button { toggle(i) } label: {
                    MoodFace(mood: i, size: 26)
                        .frame(width: 40, height: 40)
                        .background(filter == i ? Palette.moodSoft(i) : Palette.cream,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(filter == i ? Palette.mood(i) : Palette.ink.opacity(0.22),
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
        return filter == nil ? "No pages yet" : "None with this mood"
    }
    private var emptyBody: String {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty { return "Try a different word or two." }
        return filter == nil
            ? "Write your first morning page —\nit'll gather here."
            : "Try another mood, or write today's page."
    }
}
