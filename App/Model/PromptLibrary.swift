import Foundation
import Observation

@MainActor
@Observable
final class PromptLibrary {
    private(set) var builtIn: [String]
    private(set) var custom: [String]
    private(set) var selected: String?
    private let storage: PromptLibraryStorage

    init() {
        let storage = PromptLibraryStorage(defaults: SharedState.defaults, library: AppContent.journalPrompts.map(\.text))
        self.storage = storage
        builtIn = storage.builtIn
        custom = storage.custom
        selected = storage.selected
    }

    func select(_ line: String) { storage.select(line); reload() }
    @discardableResult
    func add(_ text: String) -> Bool {
        let added = storage.add(text)
        reload()
        return added
    }
    func delete(_ line: String) { storage.delete(line); reload() }
    func clear() { storage.clear(); reload() }

    private func reload() {
        builtIn = storage.builtIn
        custom = storage.custom
        selected = storage.selected
    }
}
