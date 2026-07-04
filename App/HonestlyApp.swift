import SwiftUI
import SwiftData

@main
struct HonestlyApp: App {
    @State private var premium = PremiumManager()
    @State private var screenTime = ScreenTimeManager()
    @State private var flow = AppFlow()
    @State private var l10n = LocalizationManager()
    @State private var store: JournalStore
    private let container: ModelContainer

    init() {
        DesignScale.configure(width: UIScreen.main.bounds.width)

        // App-group store, mirrored to the existing production CloudKit container so live users'
        // pages sync into the redesign. (`JournalEntry` maps to the deployed `CD_JournalEntry`.)
        // Degrade gracefully: CloudKit-synced → local-only disk → in-memory. No force-try.
        let cloud  = ModelConfiguration(groupContainer: .identifier(AppConfig.appGroupID),
                                        cloudKitDatabase: .automatic)
        let disk   = ModelConfiguration(groupContainer: .identifier(AppConfig.appGroupID))
        let memory = ModelConfiguration(isStoredInMemoryOnly: true)
        let made = (try? ModelContainer(for: JournalEntry.self, configurations: cloud))
            ?? (try? ModelContainer(for: JournalEntry.self, configurations: disk))
            ?? (try? ModelContainer(for: JournalEntry.self, configurations: memory))

        guard let made else {
            // Unreachable in practice (an in-memory store cannot fail to initialize); a clear
            // message beats a bare `try!` if the impossible ever happens.
            fatalError("Honestly could not initialize any data store.")
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
                .environment(l10n)
                .environment(\.locale, l10n.locale)                    // live String Catalog switch
                .environment(\.layoutDirection, l10n.layoutDirection)  // RTL for Arabic
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

    private func reconcileShield() {
        if store.ritualDoneToday {
            Shielding.clear()
        } else if screenTime.hasSelection, screenTime.isWithinMorningWindow() {
            Shielding.apply(BlockingCodec.load())
        }
    }
}
