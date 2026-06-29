import SwiftUI

struct TodayView: View {
    @EnvironmentObject var journalManager: JournalManager
    @EnvironmentObject var blockingManager: BlockingManager

    @State private var ritualMood: Mood?
    @State private var detailEntry: JournalEntry?
    @State private var showGarden = false
    @State private var celebrate = false

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

                Spacer(minLength: 40)
            }
            .padding(.top, 8)
            .contentColumn()
        }
        .background(Theme.pageBackground)
        .fullScreenCover(item: $ritualMood) { mood in
            RitualContainerView(mood: mood) { celebrate = true }
                .environmentObject(journalManager)
                .environmentObject(blockingManager)
        }
        .overlay {
            if celebrate {
                CompletionView(stage: journalManager.currentStage,
                               sproutCount: journalManager.sproutCount) {
                    celebrate = false
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: celebrate)
        .sheet(item: $detailEntry) { entry in
            JournalEntryDetailView(entry: entry)
                .columnSheet()
        }
        .sheet(isPresented: $showGarden) {
            GardenStagesView(currentStage: journalManager.currentStage)
                .columnSheet()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(Date().formatted(.dateTime.weekday(.wide).month(.wide).day().locale(appLocale)), size: 18)
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
