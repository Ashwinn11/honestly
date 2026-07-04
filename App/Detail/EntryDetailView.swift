import SwiftUI

struct EntryDetailView: View {
    let dayKey: String
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var entry: JournalEntry? { store.entry(for: dayKey) }

    var body: some View {
        ZStack(alignment: .top) {
            PaperBackground()
            if let entry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header(entry)
                        body(entry)
                    }
                    .capWidth(Metrics.maxContentWidth)   // centered column; PaperBackground stays full
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(.container, edges: .top)
            } else {
                missing
            }
        }
    }

    private func header(_ entry: JournalEntry) -> some View {
        let grats = entry.gratitudes.count
        return ZStack(alignment: .topTrailing) {
            SoftGlow(color: Palette.sunDisc, opacity: 0.16, size: 220)
                .offset(x: 70, y: -40)
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    IconTileButton(icon: "chevron.left", size: 38, iconSize: 15) { dismiss() }
                    Spacer()
                    ShareLink(item: shareText(entry)) {
                        IconTile(size: 38, fill: Palette.cream) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                        }
                    }
                }
                HStack(spacing: 14) {
                    MoodFace(mood: entry.moodRaw, size: 54)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(HDate.weekdayFull(entry.date)), \(HDate.monthDay(entry.date))")
                            .font(Fonts.display(26, .bold)).foregroundStyle(Palette.ink)
                        Text("\(Text(loc: entry.moodValue.label)) · \(grats) gratitudes")
                            .textCase(.uppercase)
                            .font(Fonts.ui(10.5, .heavy)).tracking(1.4).foregroundStyle(Palette.inkSofter)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 56)
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    private func body(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !entry.prompt.isEmpty {
                Eyebrow(text: "Today's prompt", color: Palette.amberDeep, tracking: 1.3, size: 11)
                    .padding(.bottom, 5)
                Text(loc: entry.prompt)
                    .font(Fonts.display(19, .semibold)).foregroundStyle(Palette.inkSoft)
                    .lineSpacing(4).padding(.bottom, 16)
            }

            RuledPaper {
                Text(entry.journal)
                    .font(Fonts.ui(16, .semibold)).foregroundStyle(Palette.ink)
                    .lineSpacing(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EdgeInsets(top: 6, leading: 16, bottom: 14, trailing: 16))
            }
            .padding(.bottom, 24)

            if !entry.gratitudes.isEmpty {
                Text("Grateful for")
                    .font(Fonts.display(20, .bold)).foregroundStyle(Palette.ink)
                    .fixedSize()
                    .underlineSquiggle(Palette.sunDisc, weight: 3.5, height: 8)
                    .padding(.bottom, 14)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(entry.gratitudes.enumerated()), id: \.offset) { i, g in
                        HStack(spacing: 12) {
                            SunMark(size: 24)
                            Text(g).font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.ink)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 9)
                        if i < entry.gratitudes.count - 1 {
                            Rectangle().fill(Palette.ink.opacity(0.07)).frame(height: 1.5)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 60)
    }

    private func shareText(_ e: JournalEntry) -> String {
        var s = "\(HDate.weekdayFull(e.date)), \(HDate.monthDay(e.date)) — \(e.moodValue.label)\n\n"
        if !e.prompt.isEmpty { s += "\(e.prompt)\n" }
        s += e.journal
        if !e.gratitudes.isEmpty {
            s += "\n\nGrateful for:\n" + e.gratitudes.map { "• \($0)" }.joined(separator: "\n")
        }
        return s
    }

    private var missing: some View {
        VStack(spacing: 14) {
            IconTileButton(icon: "chevron.left", size: 38, iconSize: 15) { dismiss() }
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            Text("This page has drifted off.").font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.inkSofter)
            Spacer()
        }
        .padding(.horizontal, 22).padding(.top, 56)
    }
}
