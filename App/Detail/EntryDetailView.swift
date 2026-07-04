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
        let isToday = HDate.isToday(entry.date)
        return ZStack(alignment: .topLeading) {
            Circle().fill(entry.moodValue.soft.opacity(0.55)).frame(width: 150, height: 150)
                .offset(x: 220, y: -36)
            VStack(alignment: .leading, spacing: 16) {
                SoftCircleButton(icon: "chevron.left", iconSize: 15) { dismiss() }
                HStack(spacing: 15) {
                    MoodFace(mood: entry.moodRaw, size: 56)
                        .padding(9)
                        .background(entry.moodValue.soft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow(text: isToday ? "Today" : HDate.weekdayFull(entry.date), size: 11.5)
                        Text(HDate.longDate(entry.date))
                            .font(Fonts.display(26, .bold)).foregroundStyle(Palette.ink)
                        Text(entry.moodValue.label)
                            .font(Fonts.ui(12, .heavy)).foregroundStyle(Palette.ink)
                            .padding(.horizontal, 12).padding(.vertical, 3)
                            .background(entry.moodValue.soft, in: Capsule())
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
                Text(entry.prompt)
                    .font(Fonts.display(20, .semibold)).foregroundStyle(Palette.inkSoft)
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
                sectionLabel("Grateful for")
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(entry.gratitudes.enumerated()), id: \.offset) { i, g in
                        HStack(spacing: 12) {
                            SunMark(size: 22)
                            Text(g).font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.ink)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)
                        if i < entry.gratitudes.count - 1 {
                            Rectangle().fill(Palette.ink.opacity(0.06)).frame(height: 1)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 60)
    }

    private func sectionLabel(_ text: String) -> some View {
        Eyebrow(text: text, color: Color(hex: "C0B29A"), tracking: 1.4, size: 11).padding(.bottom, 8)
    }

    private var missing: some View {
        VStack(spacing: 14) {
            SoftCircleButton(icon: "chevron.left", iconSize: 15) { dismiss() }
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            Text("This page has drifted off.").font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.inkSofter)
            Spacer()
        }
        .padding(.horizontal, 22).padding(.top, 56)
    }
}
