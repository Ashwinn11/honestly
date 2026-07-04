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
        guard authorized else { return }   // never touch DeviceActivity / ManagedSettings unauthorized
        armSchedule()
        if hasSelection, isWithinMorningWindow(), !SharedState.ritualCompleted() {
            Shielding.apply(new)
        } else {
            Shielding.clear()
        }
    }

    func setSelectionSilently(_ new: FamilyActivitySelection) {
        applyingProgrammatically = true
        selection = new
        applyingProgrammatically = false
    }

    // MARK: DeviceActivity schedule

    func armSchedule() {
        guard authorized else { return }
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
        if authorized { center.stopMonitoring([DeviceActivityName(AppConfig.morningScheduleName)]) }
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
