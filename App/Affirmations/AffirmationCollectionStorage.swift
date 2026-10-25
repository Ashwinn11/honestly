import Foundation

/// Stores custom lines and built-in deletions. The old selection is read once only to preserve
/// user-written lines from pre-topic versions; it no longer drives any screen or delivery surface.
struct AffirmationCollectionStorage {
    private static let legacySelectionKey = "affirmations.list"
    let defaults: UserDefaults
    let customKey: String
    let library: Set<String>
    let deletedKey: String

    init(defaults: UserDefaults, customKey: String, library: [String], deletedKey: String? = nil) {
        self.defaults = defaults
        self.customKey = customKey
        self.library = Set(library)
        self.deletedKey = deletedKey ?? customKey + ".deleted"
        let previousSelections = defaults.stringArray(forKey: Self.legacySelectionKey) ?? []
        preserveCustom(from: previousSelections)
        defaults.removeObject(forKey: Self.legacySelectionKey)
    }

    var deleted: [String] { defaults.stringArray(forKey: deletedKey) ?? [] }
    var custom: [String] { defaults.stringArray(forKey: customKey) ?? [] }

    @discardableResult
    func saveCustom(_ text: String) -> Bool {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, !library.contains(line), !custom.contains(line) else { return false }
        defaults.set(custom + [line], forKey: customKey)
        return true
    }

    func delete(_ line: String) {
        if library.contains(line) {
            var values = deleted
            guard !values.contains(line) else { return }
            values.append(line)
            defaults.set(values, forKey: deletedKey)
        } else if custom.contains(line) {
            defaults.set(custom.filter { $0 != line }, forKey: customKey)
        }
    }

    func clear() {
        defaults.removeObject(forKey: customKey)
        defaults.removeObject(forKey: deletedKey)
    }

    private func preserveCustom(from lines: [String]) {
        var seen = Set<String>()
        let merged = (custom + lines.filter { !library.contains($0) }).filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && seen.insert($0).inserted
        }
        if merged != custom { defaults.set(merged, forKey: customKey) }
    }
}
