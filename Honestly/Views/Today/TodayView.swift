import SwiftUI

struct TodayView: View {
    @EnvironmentObject var journalManager: JournalManager
    @EnvironmentObject var blockingManager: BlockingManager

    @State private var ritualMood: Mood?
    @State private var detailEntry: JournalEntry?
    @State private var showGarden = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                header

                if journalManager.isCompletedToday {
                    ShowedUpView()
                        .padding(.top, 6)
                } else {
                    MoodPickerCard { mood in ritualMood = mood }
                        .padding(.horizontal, 20)
                }

                WeekCalendarView { day in
                    detailEntry = journalManager.entry(for: day)
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 120)
            }
            .padding(.top, 8)
        }
        .fullScreenCover(item: $ritualMood) { mood in
            RitualContainerView(mood: mood)
                .environmentObject(journalManager)
                .environmentObject(blockingManager)
        }
        .sheet(item: $detailEntry) { entry in
            JournalEntryDetailView(entry: entry)
        }
        .sheet(isPresented: $showGarden) {
            GardenStagesView(currentStage: journalManager.currentStage)
                .presentationDetents([.medium, .large])
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()), size: 18)
                Text("Today")
                    .font(AppFont.title(34))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            // Tap the pot/streak to open the garden-stages guide.
            Button { showGarden = true } label: {
                HStack(spacing: 8) {
                    PlantView(stage: journalManager.currentStage, size: 52)
                    Text("\(journalManager.sproutCount)")
                        .font(AppFont.title(28))
                        .foregroundStyle(Theme.ink)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
    }
}
