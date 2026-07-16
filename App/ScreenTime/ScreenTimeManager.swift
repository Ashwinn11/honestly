import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import Observation

@MainActor
@Observable
final class ScreenTimeManager {
    var authorized: Bool = false
    var selection: FamilyActivitySelection {
        didSet { commit(selection) }
    }

    /// Kept in sync with `PremiumManager.isPremium` by `HonestlyApp`. Blocking must never run for a
    /// free or lapsed subscriber, even if Screen Time authorization was granted while premium.
    var isPremiumActive: Bool = false {
        didSet {
            guard isPremiumActive != oldValue else { return }
            armSchedule()
        }
    }

    private let center = DeviceActivityCenter()
    private var applyingProgrammatically = false

    init() {
        let loaded = BlockingCodec.load()
        selection = loaded
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    var selectedCount: Int { BlockingCodec.selectedCount }
    var hasSelection: Bool { BlockingCodec.hasSelection }

    var selectionSummary: String {
        let s = BlockingCodec.load()
        var parts: [String] = []
        let cats = s.categoryTokens.count, apps = s.applicationTokens.count, web = s.webDomainTokens.count
        if cats > 0 { parts.append("\(cats) categor\(cats == 1 ? "y" : "ies")") }
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        if web > 0 { parts.append("\(web) site\(web == 1 ? "" : "s")") }
        return parts.isEmpty ? "None yet" : parts.joined(separator: ", ")
    }

    func wipe() {
        stopMonitoring()
        applyingProgrammatically = true
        selection = FamilyActivitySelection()
        applyingProgrammatically = false
        BlockingCodec.save(FamilyActivitySelection())
        SharedState.blockingEnabled = false
        SharedState.hasEverConfiguredBlocking = false
        Shielding.clear()
    }

    func refreshAuthStatus() {
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorized = true
        } catch {
            authorized = false
        }
    }

    func ensureAuthorizedForPicker() async -> Bool {
        if !authorized { await requestAuthorization() }
        return authorized
    }

    // MARK: Selection

    private func commit(_ new: FamilyActivitySelection) {
        guard !applyingProgrammatically else { return }
        BlockingCodec.save(new)
        SharedState.hasEverConfiguredBlocking = true
        SharedState.blockingEnabled = hasSelection
        // Never touch DeviceActivity / ManagedSettings unauthorized, or for a free subscriber.
        guard authorized, isPremiumActive else { stopMonitoring(); return }
        armSchedule()
        Shielding.reconcile()
    }

    // MARK: DeviceActivity schedule

    func armSchedule() {
        guard authorized, isPremiumActive else { stopMonitoring(); return }
        let name = DeviceActivityName(AppConfig.morningScheduleName)
        guard hasSelection else { center.stopMonitoring([name]); return }
        // Already armed → leave it alone. Stop/start churn (this runs on every cold launch) is a
        // known source of missed DeviceActivity callbacks, and the schedule itself never changes.
        // If the window hours ever do change, rename `morningScheduleName` so stale schedules die.
        guard !center.activities.contains(name) else { return }
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: AppConfig.blockStartHour, minute: AppConfig.blockStartMinute),
            intervalEnd:   DateComponents(hour: AppConfig.blockEndHour,   minute: AppConfig.blockEndMinute),
            repeats: true)
        try? center.startMonitoring(name, during: schedule)
    }

    func stopMonitoring() {
        if authorized { center.stopMonitoring([DeviceActivityName(AppConfig.morningScheduleName)]) }
        Shielding.clear()
    }

    // MARK: Window helper
    func isWithinMorningWindow(_ date: Date = Date()) -> Bool {
        AppConfig.isWithinBlockWindow(date)
    }
}
