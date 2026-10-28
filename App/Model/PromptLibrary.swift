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

    /// Today's prompt as the writing page shows it, in the app's language.
    var pageText: String? { selected.map(text) }

    /// Re-reads today's prompt — it changes when the day does — and hands the coming days' prompts
    /// to the journal reminder. Call on launch, on returning to the app, and when the language
    /// changes; picking, adding and deleting prompts do it themselves.
    func refresh() { reload() }

    private func text(_ line: String) -> String {
        builtIn.contains(line) ? L10n.localized(line) : line
    }

    private func reload() {
        builtIn = storage.builtIn
        custom = storage.custom
        selected = storage.selected
        // The 04:00 extension that queues the reminder can't read the library, so leave it the
        // next two weeks of prompts, already in the app's language.
        let cal = Calendar.current
        var days: [String: String] = [:]
        for offset in 0..<14 {
            guard let date = cal.date(byAdding: .day, value: offset, to: Date()),
                  let line = storage.prompt(on: date) else { continue }
            days[SharedState.dayKey(for: date)] = text(line)
        }
        AffirmationNudge.setReminderPrompts(days)
    }
}
