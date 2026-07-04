import SwiftUI

/// Home — greeting header, the "this morning" card (unwritten → amber; done → green), the streak
/// card with its seven-day strip, and recent pages. Matches `Honestly.dc.html` lines 197–282.
struct HomeView: View {
    @Environment(JournalStore.self) private var store
    @Environment(AppFlow.self) private var flow
    @Environment(ScreenTimeManager.self) private var screenTime

    var body: some View {
        ScreenScaffold {
            VStack(alignment: .leading, spacing: 0) {
                header
                todayCard.padding(.top, 4)
                streakCard.padding(.top, 16)
                recentSection.padding(.top, 24)
            }
        }
    }

    // MARK: Header
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: HDate.homeHeader(Date()))
                Text("Good morning").font(Fonts.display(32, .bold)).foregroundStyle(Palette.ink)
            }
            Spacer()
            SunMark(size: 42, stroke: Palette.amberLight, fill: Palette.amberLight).floaty(period: 5)
        }
        .padding(.bottom, 20)
    }

    // MARK: This-morning card
    @ViewBuilder private var todayCard: some View {
        if let today = store.todayEntry {
            doneCard(today)
        } else {
            unwrittenCard
        }
    }

    private var unwrittenCard: some View {
        let count = screenTime.selectedCount
        return ZStack(alignment: .topTrailing) {
            Circle().fill(.white.opacity(0.15)).frame(width: 130, height: 130).offset(x: 34, y: -34)
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: "This morning", color: .white.opacity(0.92))
                Text("Your page isn't written yet")
                    .font(Fonts.display(26, .bold)).foregroundStyle(.white)
                    .padding(.top, 6)
                Text(count > 0
                     ? "\(count) apps are still asleep. Write your morning page to wake them up."
                     : "Write your morning page to start the day on your own terms.")
                    .font(Fonts.ui(14.5, .semibold)).foregroundStyle(.white.opacity(0.95))
                    .lineSpacing(2).frame(maxWidth: 250, alignment: .leading)
                    .padding(.top, 5)
                HStack(spacing: 10) {
                    ForEach(0..<min(max(count, 0), 3), id: \.self) { _ in sleepTile }
                    Spacer(minLength: 0)
                    if count > 0 {
                        Text("Screen Time").font(Fonts.ui(12, .bold)).foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding(.vertical, 17)
                Button { flow.startRitual() } label: {
                    Text("Write today's page →")
                        .font(Fonts.ui(16, .heavy)).foregroundStyle(Palette.amberDeep)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.14), radius: 9, y: 8)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(22)
        .background(Palette.amberGradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Palette.amber.opacity(0.34), radius: 18, y: 14)
        .staggeredAppear(index: 0)
    }
    private var sleepTile: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(.white.opacity(0.2)).frame(width: 46, height: 46)
            .overlay(alignment: .topTrailing) {
                Text("z").font(Fonts.display(13, .heavy)).foregroundStyle(.white)
                    .padding(.top, 6).padding(.trailing, 8)
            }
    }

    private func doneCard(_ entry: JournalEntry) -> some View {
        ZStack(alignment: .topTrailing) {
            Circle().fill(.white.opacity(0.4)).frame(width: 120, height: 120).offset(x: 30, y: -30)
            HStack(spacing: 15) {
                MoodFace(mood: entry.moodRaw, size: 52)
                    .padding(8)
                    .background(.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Eyebrow(text: "Today · done", color: Palette.ink.opacity(0.9), size: 11)
                    Text("Your apps are awake")
                        .font(Fonts.display(23, .bold)).foregroundStyle(Palette.ink)
                    NavigationLink(value: entry.dayKey) {
                        Text("Read today's page →")
                            .font(Fonts.ui(13.5, .heavy)).foregroundStyle(Palette.amberDeep)
                            .underline()
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .background(Palette.mood(1), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Palette.mood(1).opacity(0.34), radius: 16, y: 12)
        .staggeredAppear(index: 0)
    }

    // MARK: Streak card
    private var streakCard: some View {
        VStack(spacing: 17) {
            HStack(spacing: 13) {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "FFB067"), Palette.amberLight],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 54, height: 54)
                    .overlay(SunMark(size: 28, stroke: .white, fill: .white))
                    .shadow(color: Palette.amber.opacity(0.42), radius: 8, y: 6)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(store.streak)").font(Fonts.display(30, .heavy)).foregroundStyle(Palette.ink)
                        Text("day streak").font(Fonts.ui(14, .heavy)).foregroundStyle(Palette.inkSoft)
                    }
                    Text(streakSubtitle).font(Fonts.ui(12.5, .semibold)).foregroundStyle(Palette.inkSofter)
                }
                Spacer(minLength: 0)
            }
            HStack {
                ForEach(store.weekStrip) { cell in
                    VStack(spacing: 7) {
                        ZStack {
                            if let e = cell.entry {
                                MoodFace(mood: e.moodRaw, size: 31)
                            } else {
                                Circle()
                                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                                    .foregroundStyle(cell.isToday ? Palette.amber : Palette.ink.opacity(0.14))
                                    .frame(width: 30, height: 30)
                            }
                        }
                        .frame(width: 34, height: 34)
                        Text(cell.letter)
                            .font(Fonts.ui(11, cell.isToday ? .heavy : .bold))
                            .foregroundStyle(cell.isToday ? Palette.amber : Palette.inkSofter)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .softCard(padding: 18)
        .staggeredAppear(index: 1)
    }
    private var streakSubtitle: String {
        let s = store.streak
        if s == 0 { return "A fresh page is waiting. Begin today." }
        if s >= store.bestStreak { return "Your longest yet. Keep the sun rising." }
        return "Keep the sun rising."
    }

    // MARK: Recent pages
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent pages").font(Fonts.display(21, .bold)).foregroundStyle(Palette.ink)
                Spacer()
                if !store.entries.isEmpty {
                    Button("All →") { flow.go(to: .history) }
                        .font(Fonts.ui(13.5, .heavy)).foregroundStyle(Palette.amber)
                }
            }
            .padding(.bottom, 11)

            if store.recent.isEmpty {
                emptyRecent
            } else {
                ForEach(Array(store.recent.enumerated()), id: \.element.dayKey) { i, e in
                    NavigationLink(value: e.dayKey) {
                        EntryRow(entry: e) {
                            VStack(spacing: 1) {
                                Text("\(e.gratitudeCount)").font(Fonts.display(17, .bold)).foregroundStyle(Palette.amber)
                                Eyebrow(text: "grateful", color: Palette.inkSofter, tracking: 0.4, size: 8.5)
                            }
                        }
                    }
                    .buttonStyle(PressableStyle(scale: 0.98))
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation(Motion.snappy) { store.delete(e) }
                        } label: { Label("Delete page", systemImage: "trash") }
                    }
                    .staggeredAppear(index: i + 2)
                }
            }
        }
    }
    private var emptyRecent: some View {
        VStack(spacing: 8) {
            SunMark(size: 34, fill: nil).opacity(0.5)
            Text("Your pages will gather here.\nWrite your first one this morning.")
                .font(Fonts.ui(13.5, .semibold)).foregroundStyle(Palette.inkSofter)
                .multilineTextAlignment(.center).lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

