import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import Observation

/// The app-side controller for Screen Time. Requests Family Controls authorization, arms the
/// daily DeviceActivity window the monitor extension acts on, and applies/clears the shield for
/// immediate feedback. Persistence and shield rules live in `Shared/` (`BlockingCodec`,
/// `Shielding`) so the extensions read identical state.
@MainActor
@Observable
final class ScreenTimeManager {
    var authorized: Bool = false
    /// Bound to `FamilyActivityPicker`. Assigning commits the selection (see `didSet`).
    var selection: FamilyActivitySelection {
        didSet { commit(selection) }
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

    /// Human summary of the current selection ("2 categories, 5 apps") so the UI reflects
    /// categories instead of miscounting them all as apps.
    var selectionSummary: String {
        let s = BlockingCodec.load()
        var parts: [String] = []
        let cats = s.categoryTokens.count, apps = s.applicationTokens.count, web = s.webDomainTokens.count
        if cats > 0 { parts.append("\(cats) categor\(cats == 1 ? "y" : "ies")") }
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        if web > 0 { parts.append("\(web) site\(web == 1 ? "" : "s")") }
        return parts.isEmpty ? "None yet" : parts.joined(separator: ", ")
    }

    /// Full reset: stop the schedule, drop the selection, lift the shield.
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

    /// Prompt for Screen Time permission. Safe to call repeatedly; no-op once approved.
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorized = true
        } catch {
            authorized = false
        }
    }

    // MARK: Selection

    private func commit(_ new: FamilyActivitySelection) {
        guard !applyingProgrammatically else { return }
        BlockingCodec.save(new)
        SharedState.hasEverConfiguredBlocking = true
        SharedState.blockingEnabled = hasSelection
        armSchedule()
        // Reflect immediately: inside the morning window with the page unwritten → shield now.
        if hasSelection, isWithinMorningWindow(), !SharedState.ritualCompleted() {
            Shielding.apply(new)
        } else {
            Shielding.clear()
        }
    }

    /// Set the selection without re-committing (e.g. loading saved state into a picker binding).
    func setSelectionSilently(_ new: FamilyActivitySelection) {
        applyingProgrammatically = true
        selection = new
        applyingProgrammatically = false
    }

    // MARK: DeviceActivity schedule

    /// Arm (or re-arm) the daily block window the monitor extension responds to.
    func armSchedule() {
        let name = DeviceActivityName(AppConfig.morningScheduleName)
        center.stopMonitoring([name])
        guard hasSelection else { return }
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: AppConfig.blockStartHour, minute: AppConfig.blockStartMinute),
            intervalEnd:   DateComponents(hour: AppConfig.blockEndHour,   minute: AppConfig.blockEndMinute),
            repeats: true)
        try? center.startMonitoring(name, during: schedule)
    }

    func stopMonitoring() {
        center.stopMonitoring([DeviceActivityName(AppConfig.morningScheduleName)])
        Shielding.clear()
    }

    // MARK: Window helper
    func isWithinMorningWindow(_ date: Date = Date()) -> Bool {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let mins = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        let start = AppConfig.blockStartHour * 60 + AppConfig.blockStartMinute
        let end = AppConfig.blockEndHour * 60 + AppConfig.blockEndMinute
        return mins >= start && mins <= end
    }
}
