import Foundation
import FamilyControls

/// Persists the user's chosen apps/categories to the app group so the DeviceActivity
/// monitor can re-shield each morning without the main app running.
enum BlockingCodec {

    static func save(_ selection: FamilyActivitySelection) {
        do {
            let data = try JSONEncoder().encode(selection)
            SharedState.defaults.set(data, forKey: SharedState.Key.selectionData)
        } catch {
            // A malformed selection should never crash the ritual; drop it silently.
        }
    }

    static func load() -> FamilyActivitySelection {
        guard let data = SharedState.defaults.data(forKey: SharedState.Key.selectionData),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return selection
    }

    static var hasSelection: Bool {
        let s = load()
        return !s.applicationTokens.isEmpty
            || !s.categoryTokens.isEmpty
            || !s.webDomainTokens.isEmpty
    }

    static var selectedCount: Int {
        let s = load()
        return s.applicationTokens.count + s.categoryTokens.count + s.webDomainTokens.count
    }
}
