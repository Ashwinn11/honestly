import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import Combine

@MainActor
class BlockingManager: ObservableObject {
    static let shared = BlockingManager()

    @Published var selection: FamilyActivitySelection = FamilyActivitySelection()
    @Published var isBlocking: Bool = false
    @Published var blockingEnabled: Bool = false
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined

    private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(AppConstants.storeNameMorningBlock))
    private let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
    private let center = AuthorizationCenter.shared
    private let activityCenter = DeviceActivityCenter()

    init() {
        blockingEnabled = defaults?.bool(forKey: AppConstants.keyBlockingEnabled) ?? false
        isBlocking = defaults?.bool(forKey: AppConstants.keyIsBlocking) ?? false
        loadSelection()
        authorizationStatus = center.authorizationStatus
    }

    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(for: .individual)
            authorizationStatus = center.authorizationStatus
        } catch {
            print("FamilyControls authorization failed: \(error)")
        }
    }

    /// Re-read live status (call on Settings appear — granting happens in a system UI).
    func refreshAuthorizationStatus() {
        authorizationStatus = center.authorizationStatus
        loadSelection()
    }

    var isAuthorized: Bool { authorizationStatus == .approved }

    /// How many apps/categories the user picked to block.
    var selectedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }

    func saveSelection(_ newSelection: FamilyActivitySelection) {
        selection = newSelection
        if let data = try? JSONEncoder().encode(newSelection) {
            defaults?.set(data, forKey: AppConstants.keySelection)
        }
    }

    func startBlocking() {
        guard blockingEnabled, !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else { return }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)
        isBlocking = true
        defaults?.set(true, forKey: AppConstants.keyIsBlocking)
    }

    func stopBlocking() {
        store.clearAllSettings()
        isBlocking = false
        defaults?.set(false, forKey: AppConstants.keyIsBlocking)
    }

    func setBlockingEnabled(_ enabled: Bool) {
        blockingEnabled = enabled
        defaults?.set(enabled, forKey: AppConstants.keyBlockingEnabled)
        if enabled {
            scheduleMonitoring()
        } else {
            stopMonitoring()
            stopBlocking()
        }
    }

    // MARK: - Daily 4 AM schedule
    // The DeviceActivityMonitor extension applies the shield at intervalStart (4 AM)
    // if today's journal isn't done, and clears it at intervalEnd — so apps are
    // blocked before the user ever opens Honestly. Completing the ritual calls
    // stopBlocking() to lift the shield immediately.

    func scheduleMonitoring() {
        guard blockingEnabled else { return }
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: AppConstants.morningStartHour, minute: 0),
            intervalEnd:   DateComponents(hour: AppConstants.morningEndHour, minute: 59),
            repeats: true
        )
        do {
            try activityCenter.startMonitoring(
                DeviceActivityName(AppConstants.activityNameMorningBlock),
                during: schedule
            )
        } catch {
            print("DeviceActivity scheduling failed: \(error)")
        }
    }

    func stopMonitoring() {
        activityCenter.stopMonitoring([DeviceActivityName(AppConstants.activityNameMorningBlock)])
    }

    // MARK: - Private

    private func loadSelection() {
        guard let data = defaults?.data(forKey: AppConstants.keySelection),
              let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }
        selection = decoded
    }
}
