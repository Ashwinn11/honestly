import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct HonestlyEntry: TimelineEntry {
    let date: Date
    let mood: String
    let journalSnippet: String
    let gratitudeSnippet: String
    let sproutCount: Int
    let isCompletedToday: Bool
    let stageName: String
}

// MARK: - Provider

struct HonestlyProvider: TimelineProvider {
    private let defaults = UserDefaults(suiteName: "group.morning-journal.app")

    func placeholder(in context: Context) -> HonestlyEntry {
        HonestlyEntry(date: .now, mood: "Happy", journalSnippet: "Today I felt grateful…", gratitudeSnippet: "morning coffee", sproutCount: 12, isCompletedToday: false, stageName: "Sprout")
    }

    func getSnapshot(in context: Context, completion: @escaping (HonestlyEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HonestlyEntry>) -> Void) {
        let e = entry()
        // Refresh at midnight
        var next = Calendar.current.startOfDay(for: .now)
        next = Calendar.current.date(byAdding: .day, value: 1, to: next) ?? .now
        completion(Timeline(entries: [e], policy: .after(next)))
    }

    private func entry() -> HonestlyEntry {
        let mood = defaults?.string(forKey: "widget.mood") ?? ""
        let journal = defaults?.string(forKey: "widget.journal") ?? ""
        let gratitude = defaults?.string(forKey: "widget.gratitude") ?? ""
        let sprouts = defaults?.integer(forKey: "sproutCollectionCount") ?? 0
        let completed = isCompletedToday()
        let stage = stageName(for: sprouts)

        return HonestlyEntry(
            date: .now,
            mood: mood,
            journalSnippet: String(journal.prefix(80)),
            gratitudeSnippet: String(gratitude.prefix(60)),
            sproutCount: sprouts,
            isCompletedToday: completed,
            stageName: stage
        )
    }

    private func isCompletedToday() -> Bool {
        let completed = defaults?.bool(forKey: "todayCompleted") ?? false
        guard completed else { return false }
        if let lastDate = defaults?.object(forKey: "lastCompletionDate") as? Date {
            return Calendar.current.isDateInToday(lastDate)
        }
        return false
    }

    private func stageName(for count: Int) -> String {
        switch count {
        case 180...: return "Flowering"
        case 90...: return "Mature"
        case 30...: return "Young"
        default: return "Sprout"
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: HonestlyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("honestly")
                    .font(.custom("Caveat-SemiBold", size: 14))
                    .foregroundStyle(Color(hex: "#FF6B00"))
                Spacer()
                if entry.isCompletedToday {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#D1E4A5"))
                }
            }

            Spacer()

            Image(systemName: plantSymbol(for: entry.stageName))
                .font(.system(size: 32))
                .foregroundStyle(Color(hex: "#D1E4A5"))

            Spacer()

            Text("\(entry.sproutCount) sprouts")
                .font(.custom("Outfit-SemiBold", size: 12))
                .foregroundStyle(Color(hex: "#1C1C1C").opacity(0.5))

            Text(entry.isCompletedToday ? "Done today" : "Ritual waiting")
                .font(.custom("Outfit-Medium", size: 13))
                .foregroundStyle(Color(hex: "#1C1C1C"))
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(hex: "#F7F5F0"))
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: HonestlyEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles").font(.system(size: 12))
                    Text("honestly")
                        .font(.custom("Caveat-SemiBold", size: 16))
                }
                .foregroundStyle(Color(hex: "#FF6B00"))

                Image(systemName: plantSymbol(for: entry.stageName))
                    .font(.system(size: 36))
                    .foregroundStyle(Color(hex: "#D1E4A5"))

                Text("\(entry.sproutCount) sprouts · \(entry.stageName)")
                    .font(.custom("Outfit-Regular", size: 12))
                    .foregroundStyle(Color(hex: "#1C1C1C").opacity(0.5))
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)

            Divider()
                .overlay(Color(hex: "#1C1C1C").opacity(0.1))

            VStack(alignment: .leading, spacing: 6) {
                if entry.isCompletedToday {
                    Text("Morning done")
                        .font(.custom("Outfit-Medium", size: 15))
                        .foregroundStyle(Color(hex: "#1C1C1C"))
                    if !entry.journalSnippet.isEmpty {
                        Text(entry.journalSnippet)
                            .font(.custom("Outfit-Regular", size: 13))
                            .foregroundStyle(Color(hex: "#1C1C1C").opacity(0.55))
                            .lineLimit(3)
                    }
                } else {
                    Text("Ritual waiting")
                        .font(.custom("Outfit-Medium", size: 15))
                        .foregroundStyle(Color(hex: "#1C1C1C"))
                    Text("Pick your mood. Write.\nBe grateful. Unlock.")
                        .font(.custom("Outfit-Regular", size: 13))
                        .foregroundStyle(Color(hex: "#1C1C1C").opacity(0.55))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(16)
        .background(Color(hex: "#F7F5F0"))
    }
}

// MARK: - Lock Screen Widget

struct LockScreenWidgetView: View {
    let entry: HonestlyEntry

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: plantSymbol(for: entry.stageName))
                .font(.system(size: 14))
            Text("\(entry.sproutCount)")
                .font(.custom("Outfit-Medium", size: 14))
            Image(systemName: entry.isCompletedToday ? "checkmark" : "circle.fill")
                .font(.system(size: entry.isCompletedToday ? 11 : 5))
            Text(entry.isCompletedToday ? "Done" : "Open")
                .font(.custom("Outfit-Regular", size: 13))
        }
    }
}

// MARK: - Widget Configuration

@main
struct BigWinsWidget: WidgetBundle {
    var body: some Widget {
        HonestlyMainWidget()
        HonestlyLockScreenWidget()
    }
}

struct HonestlyMainWidget: Widget {
    let kind = "HonestlyMainWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HonestlyProvider()) { entry in
            Group {
                if #available(iOS 17, *) {
                    SmallWidgetView(entry: entry)
                        .containerBackground(Color(hex: "#F7F5F0"), for: .widget)
                } else {
                    SmallWidgetView(entry: entry)
                }
            }
        }
        .configurationDisplayName("Honestly")
        .description("See your plant and today's ritual status.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HonestlyLockScreenWidget: Widget {
    let kind = "HonestlyLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HonestlyProvider()) { entry in
            LockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("Honestly · Streak")
        .description("Quick glance at your sprout count.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Helpers

private func plantSymbol(for stageName: String) -> String {
    switch stageName {
    case "Young":     return "leaf.fill"
    case "Mature":    return "tree.fill"
    case "Flowering": return "camera.macro"   // flower glyph
    default:          return "leaf"
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
