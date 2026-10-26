import SwiftUI
import SwiftData
import UserNotifications
import WidgetKit

@main
struct HonestlyApp: App {
    @State private var premium = PremiumManager()
    @State private var screenTime = ScreenTimeManager()
    @State private var flow = AppFlow()
    @State private var l10n = LocalizationManager()
    @State private var affirmations = AffirmationList()
    @State private var prompts = PromptLibrary()
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
        let memory = ModelConfiguration(isStoredInMemoryOnly: true, groupContainer: .none, cloudKitDatabase: .none)
        let disk = ScreenshotPreview.enabled ? memory
            : ModelConfiguration(groupContainer: .identifier(AppConfig.appGroupID), cloudKitDatabase: .none)
        let made = (try? ModelContainer(for: JournalEntry.self, configurations: ScreenshotPreview.enabled ? memory : disk))
            ?? (try? ModelContainer(for: JournalEntry.self, configurations: memory))

        guard let made else {
            // Unreachable in practice (an in-memory store cannot fail to initialize); a clear
            // message beats a bare `try!` if the impossible ever happens.
            fatalError("Honestly could not initialize any data store.")
        }
        if ScreenshotPreview.enabled {
            let samples = [
                "A little more present today. I took a walk without my headphones and noticed how quiet the street can be.",
                "I don't have every answer yet, and that's okay. Today I can start with one small, kind thing.",
                ScreenshotPreview.journal,
                "A good conversation, a slow lunch, and a chapter before bed. There is a lot to be grateful for.",
                "Some days ask for less. I'm learning to listen instead of pushing through."
            ]
            for offset in 1...18 {
                let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
                let text = samples[(offset - 1) % samples.count]
                made.mainContext.insert(JournalEntry(content: text, affirmationsRaw: "",
                    mood: Mood(rawValue: (offset - 1) % 5)!.storageKey,
                    wordCount: JournalEntry.wordCount(of: text), createdAt: date,
                    tags: offset % 2 == 0 ? ["small joys"] : ["morning thoughts"]))
            }
            try? made.mainContext.save()
        }
        container = made
        _store = State(initialValue: JournalStore(context: made.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .background(KeyboardDismissalInstaller())
                .environment(store)
                .environment(premium)
                .environment(screenTime)
                .environment(flow)
                .environment(l10n)
                .environment(affirmations)
                .environment(prompts)
                .environment(\.locale, l10n.locale)                   // live String Catalog switch
                .environment(\.layoutDirection, l10n.layoutDirection)  // RTL for Arabic
                // `Text(loc:)`/literal `Text` re-resolve automatically on a locale change, but
                // plain `String`s computed from `HDate` (month/weekday names via `DateFormatter`)
                // don't — they're not observed by SwiftUI at all. Forcing a fresh identity on
                // language change rebuilds the whole tree, so those recompute too.
                .id(l10n.code)
                .modelContainer(container)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    guard let line = AppLink.affirmationLine(from: url) else { return }
                    flow.selectedTab = .home
                    flow.widgetAffirmationLine = line
                    flow.widgetAffirmationsPresented = true
                }
                .task {
                    guard !ScreenshotPreview.enabled else { return }
                    premium.configure()
                    screenTime.refreshAuthStatus()
                    // `isPremium` starts from the cached entitlement — already correct at first frame,
                    // so the schedule/shield decisions below never see a transient "free" while
                    // RevenueCat is still resolving. Seed explicitly rather than relying on
                    // `didSet` (which only fires on change).
                    screenTime.isPremiumActive = premium.isPremium
                    screenTime.armSchedule()
                    Shielding.reconcile()
                    AffirmationNudge.schedule()
                }
                .onChange(of: premium.isPremium) { _, isPremium in
                    // Apply purchases and revocations to the app and its extensions.
                    screenTime.isPremiumActive = isPremium
                    Shielding.reconcile()
                    // The widget unlocks and the rotation grows past the free cap. Flush first so
                    // the widget process sees the new `premiumActive`, not the old one.
                    SharedState.defaults.synchronize()
                    WidgetCenter.shared.reloadAllTimelines()
                    AffirmationNudge.schedule()
                }
                .onChange(of: scenePhase) { _, phase in
                    // A warm resume redraws nothing on its own: if the day rolled over while the
                    // app sat suspended, Home still shows yesterday's "done" card (no observed
                    // state changed — only the clock did) while the 04:00 extension has already
                    // re-shielded. Re-derive everything date-dependent on every return to the
                    // foreground: `reload()` re-publishes `entries` (forcing date-computed views
                    // to re-evaluate) and `reconcile()` doubles as the fallback for the days iOS
                    // drops the 04:00 DeviceActivity callback entirely.
                    guard phase == .active, !ScreenshotPreview.enabled else { return }
                    Task { await premium.refresh() }
                    store.reload()
                    screenTime.refreshAuthStatus()
                    Shielding.reconcile()
                    // Rebuilds the next two weeks of affirmation notifications.
                    AffirmationNudge.schedule()
                }
        }
    }

}
