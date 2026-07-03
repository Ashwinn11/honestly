import SwiftUI
import SwiftData

@main
struct HonestlyApp: App {
    @State private var premium = PremiumManager()
    @State private var screenTime = ScreenTimeManager()
    @State private var flow = AppFlow()
    @State private var store: JournalStore
    private let container: ModelContainer

    init() {
        // Persist into the shared app-group container so data lives alongside extension state.
        let made: ModelContainer
        do {
            let config = ModelConfiguration(groupContainer: .identifier(AppConfig.appGroupID))
            made = try ModelContainer(for: Entry.self, configurations: config)
        } catch {
            // Never fail to launch — fall back to a private on-disk store, then in-memory.
            if let disk = try? ModelContainer(for: Entry.self) {
                made = disk
            } else {
                made = try! ModelContainer(for: Entry.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            }
        }
        container = made
        _store = State(initialValue: JournalStore(context: made.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(premium)
                .environment(screenTime)
                .environment(flow)
                .modelContainer(container)
                .tint(Palette.amber)
                .preferredColorScheme(.light)
                .task {
                    premium.configure()
                    screenTime.refreshAuthStatus()
                    screenTime.armSchedule()
                    reconcileShield()
                }
        }
    }

    /// On launch, make the live shield agree with today's state: cleared once the page is written,
    /// applied if we're inside the morning window with apps selected and the page still blank.
    private func reconcileShield() {
        if store.ritualDoneToday {
            Shielding.clear()
        } else if screenTime.hasSelection, screenTime.isWithinMorningWindow() {
            Shielding.apply(BlockingCodec.load())
        }
    }
}
