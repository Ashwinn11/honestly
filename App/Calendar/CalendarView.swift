import SwiftUI

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
                    .fixedSize()
                    .underlineSquiggle(Palette.sunDisc, weight: 4, height: 9)
                Text("A month at a glance.")
                    .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSoft).padding(.top, 12)

                VStack(spacing: 0) {
                    monthNav.padding(.bottom, 12)
                    weekdayHeader
                    grid
                }
                .softCard(padding: 15, radius: 22, emphasized: true)
                .padding(.top, 18)

                moodsCard.padding(.top, 16)
            }
        }
    }

    private var monthNav: some View {
        HStack {
            IconTileButton(icon: "chevron.left", size: 34, iconSize: 12, fill: Palette.iconTile) { shift(-1) }
            Spacer()
            Text(HDate.monthTitle(monthAnchor)).font(Fonts.display(20, .bold)).foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
            Spacer()
            IconTileButton(icon: "chevron.right", size: 34, iconSize: 12, fill: Palette.iconTile) { shift(1) }
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
        let cell = Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { g in
                    let s = g.size.width
                    ZStack {
                        if let entry {
                            // A written morning shows just its mood face — no numeral.
                            MoodFace(mood: entry.moodRaw, size: s * 0.74)
                        } else if isToday {
                            Circle().stroke(Palette.amber, lineWidth: 2)
                                .frame(width: s * 0.72, height: s * 0.72)
                            Text("\(day)").font(Fonts.ui(min(s * 0.26, 14), .heavy))
                                .foregroundStyle(Palette.amberDeep)
                        } else {
                            Text("\(day)").font(Fonts.ui(min(s * 0.24, 13.5), .bold))
                                .foregroundStyle(isFuture ? Palette.dashFuture : Palette.inkMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

        if entry != nil {
            NavigationLink(value: key) { cell }.buttonStyle(PressableStyle())
        } else {
            cell
        }
    }

    private var moodsCard: some View {
        let counts = store.distribution
        let total = max(counts.reduce(0, +), 1)
        let visible = counts.filter { $0 > 0 }.count
        return VStack(alignment: .leading, spacing: 14) {
            Text("Your moods, all told").font(Fonts.display(18, .bold)).foregroundStyle(Palette.ink)
            GeometryReader { geo in
                let gaps = CGFloat(max(visible - 1, 0)) * 1.5
                let avail = geo.size.width - gaps
                HStack(spacing: 1.5) {
                    if visible == 0 {
                        Color(hex: "F2EADB")                 // empty: soft grey, not black
                    } else {
                        ForEach(0..<5, id: \.self) { i in
                            if counts[i] > 0 {
                                Palette.mood(i)
                                    .frame(width: max(2, avail * CGFloat(counts[i]) / CGFloat(total)))
                            }
                        }
                    }
                }
                .frame(height: 16)
                .background(visible >= 2 ? Palette.ink : Color.clear)   // ink only shows in the 1.5px gaps
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Palette.ink, lineWidth: 2))
            }
            .frame(height: 16)
            HStack {
                ForEach(0..<5, id: \.self) { i in
                    VStack(spacing: 5) {
                        MoodFace(mood: i, size: 34)
                        Text("\(counts[i])").font(Fonts.ui(13, .heavy)).foregroundStyle(Palette.ink)
                        Text(i == 4 ? "Crying" : Mood(rawValue: i)!.label)
                            .font(Fonts.ui(10, .bold)).foregroundStyle(Palette.inkSofter)
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
