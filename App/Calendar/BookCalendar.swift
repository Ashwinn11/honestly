import SwiftUI

/// A month book's calendar: a mood face on every morning written; tap one to open that page. It
/// isn't a page of the book — it's the other view of the book's grid, beside all the pages.
/// (This is where the old Calendar tab's grid lives now.)
struct BookCalendar: View {
    let year: Int
    let month: Int
    let entries: [JournalEntry]          // this month's pages
    var onPick: (String) -> Void

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

    init(year: Int, month: Int, entries: [JournalEntry], onPick: @escaping (String) -> Void) {
        self.year = year
        self.month = month
        self.entries = entries
        self.onPick = onPick
    }

    // Sunday-first, matching the grid's fixed layout (`leading` below assumes weekday 1 = Sunday).
    // `veryShortWeekdaySymbols` is always Sunday…Saturday regardless of the locale's first-day-of-week.
    private var weekdayLetters: [String] {
        let f = DateFormatter()
        f.locale = HDate.appLocale
        return f.veryShortWeekdaySymbols
    }

    private var first: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    private var counts: [Int] {
        var c = [0, 0, 0, 0, 0]
        for e in entries where (0...4).contains(e.moodRaw) { c[e.moodRaw] += 1 }
        return c
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            weekdayHeader
            grid
            Text("Tap a day to turn straight to it.")
                .font(Fonts.ui(13, .semibold)).foregroundStyle(Palette.inkSoft)
                .padding(.top, 18)
            moodBar.padding(.top, 24)
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
        let leading = cal.component(.weekday, from: first) - 1
        let days = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let byKey = Dictionary(entries.map { ($0.dayKey, $0) }, uniquingKeysWith: { a, _ in a })

        return LazyVGrid(columns: cols, spacing: 5) {
            ForEach(0..<leading, id: \.self) { _ in Color.clear.aspectRatio(1, contentMode: .fit) }
            ForEach(1...days, id: \.self) { day in
                let date = cal.date(from: DateComponents(year: year, month: month, day: day)) ?? first
                let key = SharedState.dayKey(for: date)
                dayCell(day: day, entry: byKey[key], key: key)
            }
        }
    }

    @ViewBuilder
    private func dayCell(day: Int, entry: JournalEntry?, key: String) -> some View {
        let cell = Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { g in
                    let s = g.size.width
                    ZStack {
                        if let entry {
                            MoodFace(mood: entry.moodRaw, size: s * 0.74)
                        } else {
                            Text("\(day)").font(Fonts.ui(min(s * 0.24, 13.5), .bold))
                                .foregroundStyle(Palette.inkMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

        if entry != nil {
            Button { Haptics.select(); onPick(key) } label: { cell }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(Text(verbatim: HDate.monthDay(entry?.date ?? first)))
        } else {
            cell.accessibilityHidden(true)
        }
    }

    // The month's moods as one bar — what used to be the Calendar tab's "all told" card, now
    // scoped to the book.
    private var moodBar: some View {
        let c = counts
        let total = max(c.reduce(0, +), 1)
        let visible = c.filter { $0 > 0 }.count
        return VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geo in
                let gaps = CGFloat(max(visible - 1, 0)) * 1.5
                let avail = geo.size.width - gaps
                HStack(spacing: 1.5) {
                    if visible == 0 {
                        Color(hex: "F2EADB")
                    } else {
                        ForEach(0..<5, id: \.self) { i in
                            if c[i] > 0 {
                                Palette.mood(i).frame(width: max(2, avail * CGFloat(c[i]) / CGFloat(total)))
                            }
                        }
                    }
                }
                .frame(height: 14)
                .background(visible >= 2 ? Palette.ink : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2))
            }
            .frame(height: 14)
            HStack {
                ForEach(0..<5, id: \.self) { i in
                    VStack(spacing: 4) {
                        MoodFace(mood: i, size: 28)
                        Text("\(c[i])").font(Fonts.ui(12, .heavy)).foregroundStyle(Palette.ink)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
