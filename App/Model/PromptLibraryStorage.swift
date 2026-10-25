import Foundation

/// English source strings identify built-ins across language changes; custom text stays verbatim.
struct PromptLibraryStorage {
    let defaults: UserDefaults
    let library: [String]
    private let customKey = "prompts.custom"
    private let deletedKey = "prompts.deleted"
    private let selectedKey = "prompts.selected"

    var custom: [String] { defaults.stringArray(forKey: customKey) ?? [] }
    var deleted: [String] { defaults.stringArray(forKey: deletedKey) ?? [] }
    var builtIn: [String] { library.filter { !deleted.contains($0) } }
    var available: [String] { builtIn + custom }
    var selected: String? {
        guard let saved = defaults.string(forKey: selectedKey), available.contains(saved) else { return available.first }
        return saved
    }

    func select(_ line: String) {
        guard available.contains(line) else { return }
        defaults.set(line, forKey: selectedKey)
    }

    @discardableResult
    func add(_ text: String) -> Bool {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, !library.contains(line), !custom.contains(line) else { return false }
        defaults.set(custom + [line], forKey: customKey)
        select(line)
        return true
    }

    func delete(_ line: String) {
        guard available.contains(line) else { return }
        let wasSelected = selected == line
        if library.contains(line) {
            defaults.set(deleted + [line], forKey: deletedKey)
        } else {
            defaults.set(custom.filter { $0 != line }, forKey: customKey)
        }
        if wasSelected {
            if let next = available.first { defaults.set(next, forKey: selectedKey) }
            else { defaults.removeObject(forKey: selectedKey) }
        }
    }

    func clear() {
        [customKey, deletedKey, selectedKey].forEach { defaults.removeObject(forKey: $0) }
    }
}
