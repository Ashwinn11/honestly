import SwiftUI

struct EntryRow<Trailing: View>: View {
    let entry: JournalEntry
    @ViewBuilder var trailing: () -> Trailing

    private var isToday: Bool { HDate.isToday(entry.date) }

    var body: some View {
        HStack(spacing: 13) {
            MoodFace(mood: entry.moodRaw, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(isToday ? "This morning" : HDate.monthDay(entry.date))
                        .font(Fonts.ui(13.5, .heavy)).foregroundStyle(Palette.ink)
                    Text(isToday ? "Today" : HDate.weekdayShort(entry.date))
                        .font(Fonts.ui(11, .semibold)).foregroundStyle(Palette.inkMuted)
                }
                Text(entry.journal).font(Fonts.ui(13, .medium)).foregroundStyle(Palette.inkSoft)
                    .lineLimit(2).multilineTextAlignment(.leading).lineSpacing(1)
            }
            Spacer(minLength: 6)
            trailing()
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color(hex: "78501E").opacity(0.07), radius: 11, y: 8)
    }
}
