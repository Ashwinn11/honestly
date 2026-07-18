import SwiftUI

// Deliberately no image/tag preview here — those belong to the full page in `EntryDetailView`.
// A History card is a compact index (mood, date, a two-line text snippet); decoding RTFD to pull
// a thumbnail and rendering tag chips per row bloated both the card's height and the list's
// per-row work for a scan-the-list surface that doesn't need it.
struct EntryRow<Trailing: View>: View {
    let entry: JournalEntry
    @ViewBuilder var trailing: () -> Trailing

    private var isToday: Bool { HDate.isToday(entry.date) }

    var body: some View {
        HStack(spacing: 13) {
            MoodFace(mood: entry.moodRaw, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    (isToday ? Text("This morning") : Text(HDate.monthDay(entry.date)))
                        .font(Fonts.ui(13.5, .heavy)).foregroundStyle(Palette.ink)
                    (isToday ? Text("Today") : Text(HDate.weekdayShort(entry.date)))
                        .font(Fonts.ui(11, .semibold)).foregroundStyle(Palette.inkMuted)
                }
                Text(entry.journal).font(Fonts.ui(13, .medium)).foregroundStyle(Palette.inkSoft)
                    .lineLimit(2).multilineTextAlignment(.leading).lineSpacing(1)
            }
            Spacer(minLength: 6)
            trailing()
        }
        .padding(13)
        .background(Palette.cream, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Palette.outlineSoft, lineWidth: 1.5))
        .shadow(color: Color(hex: "78501E").opacity(0.07), radius: 11, y: 8)
    }
}

/// The affirmation-count flourish on the right of a page card — a small gold sun disc + the count.
struct EntryScore: View {
    let count: Int
    var body: some View {
        VStack(spacing: 1) {
            SunMark(size: 20, rays: false)
            Text("\(count)").font(Fonts.display(13, .bold)).foregroundStyle(Palette.ink)
        }
        .frame(minWidth: 24)
    }
}
