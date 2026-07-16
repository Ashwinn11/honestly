import Foundation
import FamilyControls
import ManagedSettings

enum Shielding {
    static let storeName = ManagedSettingsStore.Name("honestlyMorningBlock")
    static let store = ManagedSettingsStore(named: storeName)

    static func apply(_ selection: FamilyActivitySelection) {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    static func applySaved() {
        apply(BlockingCodec.load())
    }

    /// The one decision point for "should the shield be up right now?". Launch, ritual save,
    /// page delete, selection changes, and the 04:00 monitor callback all funnel here instead of
    /// re-deriving the answer from different inputs — which is exactly how the app and the
    /// extension once disagreed. Reads only app-group state, so every process computes the same
    /// answer. (The 23:59 interval-end stays a plain `clear()`: the window is still "open" at
    /// that exact minute, so reconciling there would re-shield.)
    static func reconcile(now: Date = Date()) {
        let shouldShield = SharedState.premiumActive
            && BlockingCodec.hasSelection
            && AppConfig.isWithinBlockWindow(now)
            && !SharedState.ritualCompleted(on: now)
        if shouldShield { applySaved() } else { clear() }
    }

    static func clear() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }
}
