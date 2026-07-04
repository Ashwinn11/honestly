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

    static func clear() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }
}
