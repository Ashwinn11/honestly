import Foundation

/// English source strings identify built-ins across language changes; custom text stays verbatim.
/// Each day's page gets the next prompt in the library; picking another one changes that day only.
struct PromptLibraryStorage {
    let defaults: UserDefaults
    let library: [String]
    private let customKey = "prompts.custom"
    private let deletedKey = "prompts.deleted"
    private let selectedKey = "prompts.selected"
    private let selectedDayKey = "prompts.selectedDay"      // the day the pick above was made for

    var custom: [String] { defaults.stringArray(forKey: customKey) ?? [] }
    var deleted: [String] { defaults.stringArray(forKey: deletedKey) ?? [] }
    var builtIn: [String] { library.filter { !deleted.contains($0) } }
    var available: [String] { builtIn + custom }
    /// Today's prompt.
    var selected: String? { prompt(on: Date()) }

    /// The day's prompt: the user's pick if they changed it that day, otherwise the library's
    /// turn for that date — so every day opens on a different prompt.
    func prompt(on date: Date) -> String? {
        let list = available
        guard !list.isEmpty else { return nil }
        if defaults.string(forKey: selectedDayKey) == SharedState.dayKey(for: date),
           let saved = defaults.string(forKey: selectedKey), list.contains(saved) {
            return saved
        }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return list[day % list.count]
    }

    /// Swaps today's prompt; tomorrow goes back to the daily turn.
    func select(_ line: String) {
        guard available.contains(line) else { return }
        defaults.set(line, forKey: selectedKey)
        defaults.set(SharedState.dayKey(), forKey: selectedDayKey)
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
        if library.contains(line) {
            defaults.set(deleted + [line], forKey: deletedKey)
        } else {
            defaults.set(custom.filter { $0 != line }, forKey: customKey)
        }
        if defaults.string(forKey: selectedKey) == line {
            [selectedKey, selectedDayKey].forEach { defaults.removeObject(forKey: $0) }
        }
    }

    func clear() {
        [customKey, deletedKey, selectedKey, selectedDayKey].forEach { defaults.removeObject(forKey: $0) }
    }
}
