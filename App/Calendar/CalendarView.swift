import SwiftUI

/// Calendar — a month grid with a mood face on every written day, month navigation, a count card,
/// and the mood legend. Matches `Honestly.dc.html` lines 373–419.
struct CalendarView: View {
    @Environment(JournalStore.self) private var store
    @State private var monthAnchor = Calendar.current.startOfDay(
        for: Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!)

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
    private let weekdayLetters = ["S", "M", "T", "W", "T", "F", "S"]

    private var comps: (year: Int, month: Int) {
        let c = Calendar.current.dateComponents([.year, .month], from: monthAnchor)
        return (c.year!, c.month!)
    }

    var body: some View {
        ScreenScaffold {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your mornings").font(Fonts.display(30, .bold)).foregroundStyle(Palette.ink)
                Text("A dot of color for every page you wrote.")
                    .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSoft).padding(.top, 5)

                monthNav.padding(.top, 20).padding(.bottom, 10)
                weekdayHeader
                grid
                countCard.padding(.top, 18)
                moodsCard.padding(.top, 16)
            }
        }
    }

    private var monthNav: some View {
        HStack {
            SoftCircleButton(icon: "chevron.left", diameter: 36, iconSize: 13, shadow: true) { shift(-1) }
            Spacer()
            Text(HDate.monthTitle(monthAnchor)).font(Fonts.display(21, .bold)).foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
            Spacer()
            SoftCircleButton(icon: "chevron.right", diameter: 36, iconSize: 13, shadow: true) { shift(1) }
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: cols, spacing: 0) {
            ForEach(Array(weekdayLetters.enumerated()), id: \.offset) { _, l in
                Text(l).font(Fonts.ui(11, .heavy)).foregroundStyle(Palette.inkMuted).padding(.vertical, 4)
            }
        }
        .padding(.bottom, 4)
    }

    private var grid: some View {
        let cal = Calendar.current
        let first = cal.date(from: DateComponents(year: comps.year, month: comps.month, day: 1))!
        let leading = cal.component(.weekday, from: first) - 1
        let days = cal.range(of: .day, in: .month, for: first)!.count
        let today = cal.startOfDay(for: Date())

        return LazyVGrid(columns: cols, spacing: 5) {
            ForEach(0..<leading, id: \.self) { _ in Color.clear.aspectRatio(1, contentMode: .fit) }
            ForEach(1...days, id: \.self) { day in
                let date = cal.date(from: DateComponents(year: comps.year, month: comps.month, day: day))!
                let key = SharedState.dayKey(for: date)
                let entry = store.entry(for: key)
                let isToday = cal.isDate(date, inSameDayAs: today)
                let isFuture = date > today
                dayCell(day: day, entry: entry, key: key, isToday: isToday, isFuture: isFuture)
            }
        }
    }

    @ViewBuilder
    private func dayCell(day: Int, entry: JournalEntry?, key: String, isToday: Bool, isFuture: Bool) -> some View {
        // Color.clear + aspectRatio pins each cell to a perfect square of the column width, so the
        // today ring reads as a rounded square (not a stretched pill) and faces never crowd.
        let cell = Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { g in
                    let s = g.size.width
                    ZStack {
                        RoundedRectangle(cornerRadius: s * 0.28, style: .continuous)
                            .fill(cellBG(entry: entry, isToday: isToday))
                        if isToday {
                            RoundedRectangle(cornerRadius: s * 0.28, style: .continuous)
                                .stroke(Palette.amber, lineWidth: 2)
                        }
                        VStack(spacing: 1) {
                            if let entry { MoodFace(mood: entry.moodRaw, size: s * 0.56) }
                            Text("\(day)")
                                .font(Fonts.ui(min(s * 0.24, 11), .bold))
                                .foregroundStyle(entry != nil ? Palette.inkSoft
                                                 : (isFuture ? Palette.dashFuture : Palette.inkSofter))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }

        if entry != nil {
            NavigationLink(value: key) { cell }.buttonStyle(PressableStyle())
        } else {
            cell
        }
    }

    private func cellBG(entry: JournalEntry?, isToday: Bool) -> Color {
        if entry != nil { return .white.opacity(0.65) }
        if isToday { return Palette.amber.opacity(0.08) }
        return .clear
    }

    private var countCard: some View {
        HStack(spacing: 14) {
            Text("\(store.monthCount(year: comps.year, month: comps.month))")
                .font(Fonts.display(30, .heavy)).foregroundStyle(Palette.amber)
            Text("mornings written\nin \(HDate.monthShort(monthAnchor))")
                .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSoft).lineSpacing(1)
            Spacer(minLength: 0)
        }
        .softCard(padding: 16, radius: 20)
    }

    /// "Your moods, all told" — moved here from the You tab (this is where it makes most sense).
    /// Merges the distribution bar with the mood legend (face · count · label).
    private var moodsCard: some View {
        let counts = store.distribution
        let total = max(counts.reduce(0, +), 1)
        return VStack(alignment: .leading, spacing: 14) {
            Text("Your moods, all told").font(Fonts.display(19, .bold)).foregroundStyle(Palette.ink)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        if counts[i] > 0 {
                            Palette.mood(i)
                                .frame(width: max(2, (geo.size.width - 8) * CGFloat(counts[i]) / CGFloat(total)))
                        }
                    }
                    if counts.allSatisfy({ $0 == 0 }) { Palette.ink.opacity(0.06) }
                }
                .frame(height: 16)
                .clipShape(Capsule())
            }
            .frame(height: 16)
            HStack {
                ForEach(0..<5, id: \.self) { i in
                    VStack(spacing: 5) {
                        MoodFace(mood: i, size: 26)
                        Text("\(counts[i])").font(Fonts.ui(12, .heavy)).foregroundStyle(Palette.ink)
                        Text(Mood(rawValue: i)!.label).font(Fonts.ui(10, .bold)).foregroundStyle(Palette.inkSofter)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .softCard(padding: 18, radius: 22)
    }

    private func shift(_ delta: Int) {
        withAnimation(Motion.snappy) {
            monthAnchor = Calendar.current.date(byAdding: .month, value: delta, to: monthAnchor) ?? monthAnchor
        }
    }
}
