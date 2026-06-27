import SwiftUI

struct JournalView: View {
    @EnvironmentObject var journalManager: JournalManager
    @State private var searching = false
    @State private var query = ""

    private var days: [JournalDay] {
        if query.isEmpty { return journalManager.groupedByDay }
        let filtered = journalManager.search(query)
        return Dictionary(grouping: filtered) { $0.dayKey }
            .map { JournalDay(key: $0.key, date: $0.value.first?.date ?? Date(),
                              entries: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.pageBackground
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        if searching { searchField }
                        SproutCollectionCard()
                            .padding(.horizontal, 20)

                        ForEach(days) { day in
                            daySection(day)
                        }
                        Spacer(minLength: 120)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow("your little book of", size: 18)
                Text("mornings")
                    .font(AppFont.title(34))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            Button { withAnimation { searching.toggle() } } label: {
                Image(systemName: searching ? "xmark" : "magnifyingglass")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 50, height: 50)
                    .background(Theme.card).clipShape(Circle())
                    .overlay(Circle().stroke(Theme.ink, lineWidth: Theme.borderWidth))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
    }

    private var searchField: some View {
        TextField("search your mornings…", text: $query)
            .font(AppFont.body(16))
            .padding(.horizontal, 16).padding(.vertical, 12)
            .appCardStyle(radius: 16, fill: Theme.card)
            .padding(.horizontal, 24)
    }

    private func daySection(_ day: JournalDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dayLabel(day.date))
                .font(AppFont.accent(18))
                .foregroundStyle(Theme.inkFaint)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Theme.inkGhost)
                .clipShape(Capsule())
                .padding(.horizontal, 24)

            ForEach(day.entries) { entry in
                NavigationLink {
                    JournalEntryDetailView(entry: entry)
                        .navigationBarHidden(true)
                } label: {
                    EntryRow(entry: entry)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
        }
    }

    private func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}

// MARK: - Entry row

private struct EntryRow: View {
    let entry: JournalEntry

    var body: some View {
        AppCard(padding: 16, radius: 20) {
            HStack(alignment: .top, spacing: 14) {
                MoodFace(mood: entry.mood, size: 52)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Spacer()
                        Text(entry.date.formatted(.dateTime.hour().minute()))
                            .font(AppFont.caption(12))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    Text(entry.content.isEmpty ? "—" : entry.content)
                        .font(AppFont.body(16))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if !entry.gratitude.isEmpty {
                        HStack(spacing: 5) {
                            Text("❤️").font(.system(size: 12))
                            Text(entry.gratitude)
                                .font(AppFont.body(14))
                                .foregroundStyle(Theme.inkFaint)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Sprout collection card

private struct SproutCollectionCard: View {
    @EnvironmentObject var journalManager: JournalManager

    private let milestones = AppConstants.plantStageThresholds   // [0,30,90,180]
    private var maxMilestone: Int { milestones.last ?? 180 }
    private var fraction: CGFloat {
        CGFloat(min(journalManager.sproutCount, maxMilestone)) / CGFloat(maxMilestone)
    }

    var body: some View {
        AppCard(padding: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 6) {
                    PlantView(stage: journalManager.currentStage, size: 64)
                    Text(journalManager.currentStage.displayName.capitalized)
                        .font(AppFont.accent(18))
                        .foregroundStyle(Theme.orange)
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Text("Sprout collection")
                            .font(AppFont.accent(20))
                            .foregroundStyle(Theme.ink)
                        Text("\(journalManager.sproutCount)")
                            .font(AppFont.title(22))
                            .foregroundStyle(Theme.orange)
                    }
                    progressBar
                    HStack {
                        ForEach(Array(zip(milestones.indices, milestones)), id: \.0) { i, m in
                            VStack(spacing: 2) {
                                Text(i == milestones.count - 1 ? "\(m)+" : "\(m)")
                                    .font(AppFont.captionBold(13))
                                Text(PlantStage(rawValue: i)?.displayName.capitalized ?? "")
                                    .font(AppFont.caption(11))
                                    .foregroundStyle(Theme.inkFaint)
                            }
                            .frame(maxWidth: .infinity, alignment: i == 0 ? .leading : (i == milestones.count - 1 ? .trailing : .center))
                        }
                    }
                    Text("watch the plant grow as you cross a milestone.")
                        .font(AppFont.accent(15))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.inkGhost)
                Capsule().fill(Theme.confused)
                    .frame(width: max(14, geo.size.width * fraction))
                    .overlay(Capsule().stroke(Theme.ink, lineWidth: 1.5))
            }
        }
        .frame(height: 14)
        .overlay(Capsule().stroke(Theme.ink, lineWidth: 1.5))
    }
}
