import Foundation

/// Saved custom statements outlive their membership in the daily collection.
struct AffirmationCollectionStorage {
    let defaults: UserDefaults
    let selectionKey: String
    let customKey: String
    let library: Set<String>
    let fallback: [String]
    let deletedKey: String
    private let orderedLibrary: [String]

    init(defaults: UserDefaults, selectionKey: String, customKey: String,
         library: [String], fallback: [String], deletedKey: String? = nil) {
        self.defaults = defaults
        self.selectionKey = selectionKey
        self.customKey = customKey
        self.library = Set(library)
        self.fallback = fallback
        self.deletedKey = deletedKey ?? customKey + ".deleted"
        self.orderedLibrary = library
        // Migrate older installations before a deselection can discard a custom statement.
        preserveCustom(from: selection)
    }

    var deleted: [String] { defaults.stringArray(forKey: deletedKey) ?? [] }
    var selection: [String] { (defaults.stringArray(forKey: selectionKey) ?? []).filter { !deleted.contains($0) } }
    var custom: [String] { defaults.stringArray(forKey: customKey) ?? [] }
    var replacementSelection: [String] {
        let preferred = fallback.filter { !deleted.contains($0) }
        return preferred.isEmpty ? Array(orderedLibrary.filter { !deleted.contains($0) }.prefix(1)) : preferred
    }

    func setSelection(_ lines: [String]) {
        let clean = unique(lines).filter { !deleted.contains($0) }
        preserveCustom(from: clean)
        defaults.set(clean, forKey: selectionKey)
    }

    @discardableResult
    func saveCustom(_ text: String) -> Bool {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, !library.contains(line), !custom.contains(line) else { return false }
        defaults.set(custom + [line], forKey: customKey)
        return true
    }

    func delete(_ line: String) {
        guard library.contains(line) || custom.contains(line) else { return }
        let wasSelected = selection.contains(line)
        let remaining = selection.filter { $0 != line }
        if library.contains(line) {
            defaults.set(unique(deleted + [line]), forKey: deletedKey)
        } else {
            defaults.set(custom.filter { $0 != line }, forKey: customKey)
        }
        // Never resurrect a deleted built-in when removing the final selected line.
        if wasSelected {
            defaults.set(remaining.isEmpty ? replacementSelection : remaining, forKey: selectionKey)
        }
    }

    func clear() {
        defaults.removeObject(forKey: selectionKey)
        defaults.removeObject(forKey: customKey)
        defaults.removeObject(forKey: deletedKey)
    }

    private func preserveCustom(from lines: [String]) {
        let saved = unique(custom + lines.filter { !library.contains($0) })
        if saved != custom { defaults.set(saved, forKey: customKey) }
    }

    private func unique(_ lines: [String]) -> [String] {
        var seen = Set<String>()
        return lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && seen.insert($0).inserted }
    }
}
