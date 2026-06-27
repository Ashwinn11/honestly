import SwiftUI

/// "this week / your little garden" calendar. Collapsed = current week row,
/// expanded = full month grid. Days with entries show a mood-colored marker.
struct WeekCalendarView: View {
    @EnvironmentObject var journalManager: JournalManager
    var onSelectDay: (Date) -> Void

    @State private var expanded = false
    @State private var monthAnchor = Date()

    private let cal = Calendar.current

    var body: some View {
        AppCard(padding: 18, fill: Theme.card) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("this week")
                        .font(AppFont.bodyBold(17))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    HStack(spacing: 4) {
                        Eyebrow("your little garden", color: Theme.inkFaint, size: 16)
                        Mascot(kind: .clover, size: 18)
                    }
                }

                // Month + controls
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(monthAnchor.formatted(.dateTime.month(.wide)))
                            .font(AppFont.cardTitle(22))
                            .foregroundStyle(Theme.ink)
                        Text(monthAnchor.formatted(.dateTime.year()))
                            .font(AppFont.caption(14))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    Spacer()
                    if expanded {
                        roundArrow("chevron.left") { shiftMonth(-1) }
                        roundArrow("chevron.right") { shiftMonth(1) }
                    }
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { expanded.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Text(expanded ? "less" : "month")
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        }
                        .font(AppFont.caption(14))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Theme.inkGhost)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                weekdayHeader
                if expanded { monthGrid } else { weekRow }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: header

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            // Index as id — letters repeat (S, T) so \.self would collide.
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, d in
                Text(d)
                    .font(AppFont.caption(12))
                    .foregroundStyle(Theme.inkFaint)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var weekdaySymbols: [String] {
        let base = ["S", "M", "T", "W", "T", "F", "S"]
        return Array(base[cal.firstWeekday - 1 ..< 7] + base[0 ..< cal.firstWeekday - 1])
    }

    // MARK: week row (collapsed)

    private var weekRow: some View {
        HStack(spacing: 0) {
            ForEach(daysInCurrentWeek(), id: \.self) { day in
                dayCell(day, inMonth: true)
            }
        }
    }

    // MARK: month grid (expanded)

    private var monthGrid: some View {
        let days = daysInMonthGrid()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day { dayCell(day, inMonth: true) } else { Color.clear.frame(height: 40) }
            }
        }
    }

    // MARK: day cell

    private func dayCell(_ day: Date, inMonth: Bool) -> some View {
        let isToday = cal.isDateInToday(day)
        let mood = journalManager.mood(on: day)
        return Button {
            if journalManager.entry(for: day) != nil { onSelectDay(day) }
        } label: {
            ZStack {
                if let mood {
                    MoodFace(mood: mood, size: 34)
                } else if isToday {
                    Circle().fill(Theme.orange)
                        .frame(width: 36, height: 36)
                    Text("\(cal.component(.day, from: day))")
                        .font(AppFont.bodyBold(15))
                        .foregroundStyle(.white)
                } else {
                    Text("\(cal.component(.day, from: day))")
                        .font(AppFont.body(15))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.plain)
        .disabled(mood == nil)
    }

    // MARK: helpers

    private func roundArrow(_ name: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 32, height: 32)
                .overlay(Circle().stroke(Theme.inkGhost, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func shiftMonth(_ by: Int) {
        if let d = cal.date(byAdding: .month, value: by, to: monthAnchor) {
            withAnimation { monthAnchor = d }
        }
    }

    private func daysInCurrentWeek() -> [Date] {
        guard let interval = cal.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: interval.start) }
    }

    /// Month grid with leading nils so the 1st lands on the right weekday.
    private func daysInMonthGrid() -> [Date?] {
        guard let monthInterval = cal.dateInterval(of: .month, for: monthAnchor) else { return [] }
        let firstDay = monthInterval.start
        let dayCount = cal.range(of: .day, in: .month, for: monthAnchor)?.count ?? 30
        let leading = (cal.component(.weekday, from: firstDay) - cal.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for i in 0..<dayCount {
            cells.append(cal.date(byAdding: .day, value: i, to: firstDay))
        }
        return cells
    }
}
