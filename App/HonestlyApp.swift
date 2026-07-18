import SwiftUI
import SwiftData
import UserNotifications

@main
struct HonestlyApp: App {
    @State private var premium = PremiumManager()
    @State private var screenTime = ScreenTimeManager()
    @State private var flow = AppFlow()
    @State private var l10n = LocalizationManager()
    @State private var store: JournalStore
    @Environment(\.scenePhase) private var scenePhase
    private let container: ModelContainer

    init() {
        DesignScale.configure(width: UIScreen.main.bounds.width)
        UNUserNotificationCenter.current().delegate = AffirmationNudge.ForegroundPresenter.shared

        // App-group store, local-only. iCloud is never touched automatically — the only sync path
        // is the explicit "Back up to iCloud" action in Profile (`CloudBackup`). SwiftData's
        // automatic CloudKit mirroring used to run here too, but it silently and continuously
        // failed: fields added since the app's original Core Data schema (`affirmationsRaw`,
        // `richContent`, `tags`) were never deployed to the container's *production* schema, and
        // CloudKit rejects any client-side schema change there (Development-only, deploy-to-
        // production is a manual Dashboard step) — every background save attempt errored out.
        // `cloudKitDatabase` defaults to `.automatic` when omitted — it must be passed as `.none`
        // explicitly, or the store silently mirrors to CloudKit anyway.
        // Degrade gracefully: disk → in-memory. No force-try.
        let disk   = ModelConfiguration(groupContainer: .identifier(AppConfig.appGroupID), cloudKitDatabase: .none)
        let memory = ModelConfiguration(isStoredInMemoryOnly: true)
        let made = (try? ModelContainer(for: JournalEntry.self, configurations: disk))
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
                // `Text(loc:)`/literal `Text` re-resolve automatically on a locale change, but
                // plain `String`s computed from `HDate` (month/weekday names via `DateFormatter`)
                // don't — they're not observed by SwiftUI at all. Forcing a fresh identity on
                // language change rebuilds the whole tree, so those recompute too.
                .id(l10n.code)
                .modelContainer(container)
                .preferredColorScheme(.light)
                .task {
                    premium.configure()
                    screenTime.refreshAuthStatus()
                    // `isPremium` is the persisted lifetime flag — already correct at first frame,
                    // so the schedule/shield decisions below never see a transient "free" while
                    // RevenueCat is still resolving. Seed explicitly rather than relying on
                    // `didSet` (which only fires on change).
                    screenTime.isPremiumActive = premium.isPremium
                    screenTime.armSchedule()
                    Shielding.reconcile()
                }
                .onChange(of: premium.isPremium) { _, isPremium in
                    // Fires once in the app's life: the moment the lifetime unlock ratchets on.
                    screenTime.isPremiumActive = isPremium
                    Shielding.reconcile()
                }
                .onChange(of: scenePhase) { _, phase in
                    // A warm resume redraws nothing on its own: if the day rolled over while the
                    // app sat suspended, Home still shows yesterday's "done" card (no observed
                    // state changed — only the clock did) while the 04:00 extension has already
                    // re-shielded. Re-derive everything date-dependent on every return to the
                    // foreground: `reload()` re-publishes `entries` (forcing date-computed views
                    // to re-evaluate) and `reconcile()` doubles as the fallback for the days iOS
                    // drops the 04:00 DeviceActivity callback entirely.
                    guard phase == .active else { return }
                    store.reload()
                    screenTime.refreshAuthStatus()
                    Shielding.reconcile()
                }
        }
    }

}
