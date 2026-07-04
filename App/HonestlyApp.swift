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
        // Responsive scale for the whole UI — 1.0 on iPhone, larger on iPad. Portrait-locked +
        // full-screen, so the launch width is the stable device width.
        DesignScale.configure(width: UIScreen.main.bounds.width)

        // App-group store, mirrored to the existing production CloudKit container so live users'
        // pages sync into the redesign. (`JournalEntry` maps to the deployed `CD_JournalEntry`.)
        let made: ModelContainer
        do {
            let config = ModelConfiguration(groupContainer: .identifier(AppConfig.appGroupID),
                                            cloudKitDatabase: .automatic)
            made = try ModelContainer(for: JournalEntry.self, configurations: config)
        } catch {
            // Never fail to launch — fall back to a local store if CloudKit can't init.
            if let disk = try? ModelContainer(for: JournalEntry.self,
                                              configurations: ModelConfiguration(groupContainer: .identifier(AppConfig.appGroupID))) {
                made = disk
            } else {
                made = try! ModelContainer(for: JournalEntry.self,
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
