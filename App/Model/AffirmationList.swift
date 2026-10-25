import Foundation
import Observation
import WidgetKit

/// Shared affirmation content and preferences for the feed, favorites, reminders, and widgets.
@MainActor
@Observable
final class AffirmationList {
    private(set) var savedCustom: [String]
    private(set) var deletedBuiltIns: [String]
    private(set) var favorites: [String]
    private(set) var readingHistory: [String]
    private(set) var selectedTopics: [String]
    private let storage: AffirmationCollectionStorage

    init() {
        let storage = AffirmationCollectionStorage(
            defaults: SharedState.defaults,
            customKey: SharedState.Key.customAffirmations,
            library: Affirmations.library.flatMap(\.lines),
            deletedKey: SharedState.Key.deletedAffirmations)
        self.storage = storage
        savedCustom = storage.custom
        deletedBuiltIns = storage.deleted
        favorites = SharedState.defaults.stringArray(forKey: SharedState.Key.affirmationFavorites) ?? []
        readingHistory = SharedState.defaults.stringArray(forKey: SharedState.Key.affirmationHistory) ?? []
        let defaults = SharedState.defaults
        let topicsKey = SharedState.Key.affirmationTopics
        let needsTopicMigration = defaults.object(forKey: topicsKey) == nil
        if !needsTopicMigration {
            selectedTopics = Affirmations.selectedTopics
        } else if let oldFeedSelection = defaults.stringArray(forKey: SharedState.Key.affirmationFeedFocuses) {
            selectedTopics = oldFeedSelection
        } else {
            // Migrate old separate reminder/widget choices into the one shared topic selection.
            let legacy = (defaults.stringArray(forKey: SharedState.Key.affirmationReminderFocuses) ?? [])
                + (defaults.stringArray(forKey: SharedState.Key.affirmationWidgetFocuses) ?? [])
            selectedTopics = legacy.reduce(into: []) { result, title in
                if !result.contains(title) { result.append(title) }
            }
        }
        Affirmations.selectedTopics = selectedTopics
        defaults.removeObject(forKey: SharedState.Key.affirmationFeedFocuses)
        defaults.removeObject(forKey: SharedState.Key.affirmationReminderFocuses)
        defaults.removeObject(forKey: SharedState.Key.affirmationWidgetFocuses)
        selectedTopics = migrateTopicNames(selectedTopics)
        selectedTopics = normalizedFocuses(selectedTopics)
        Affirmations.selectedTopics = selectedTopics
        if needsTopicMigration {
            WidgetCenter.shared.reloadAllTimelines()
            AffirmationNudge.schedule()
        }
    }

    var availableLibrary: [Affirmations.Focus] {
        Affirmations.library.compactMap { focus in
            let lines = focus.lines.filter { !deletedBuiltIns.contains($0) }
            return lines.isEmpty ? nil : .init(title: focus.title, lines: lines)
        }
    }

    func setSelectedTopics(_ topics: [String]) {
        let cleaned = normalizedFocuses(topics)
        guard selectedTopics != cleaned else { return }
        selectedTopics = cleaned
        Affirmations.selectedTopics = cleaned
        refreshDelivery()
    }

    @discardableResult
    func saveCustom(_ line: String) -> Bool {
        let added = storage.saveCustom(line)
        savedCustom = storage.custom
        if added { refreshDelivery() }
        return added
    }

    func delete(_ line: String) {
        storage.delete(line)
        savedCustom = storage.custom
        deletedBuiltIns = storage.deleted
        favorites.removeAll { $0 == line }
        readingHistory.removeAll { $0 == line }
        SharedState.defaults.set(favorites, forKey: SharedState.Key.affirmationFavorites)
        SharedState.defaults.set(readingHistory, forKey: SharedState.Key.affirmationHistory)
        if savedCustom.isEmpty {
            selectedTopics.removeAll { $0 == "Your own" }
            Affirmations.selectedTopics = selectedTopics
        }
        selectedTopics = normalizedFocuses(selectedTopics)
        Affirmations.selectedTopics = selectedTopics
        refreshDelivery()
    }

    func toggleFavorite(_ line: String) {
        if favorites.contains(line) { favorites.removeAll { $0 == line } }
        else { favorites.insert(line, at: 0) }
        SharedState.defaults.set(favorites, forKey: SharedState.Key.affirmationFavorites)
    }

    func recordRead(_ line: String) {
        guard !line.isEmpty else { return }
        readingHistory.removeAll { $0 == line }
        readingHistory.insert(line, at: 0)
        if readingHistory.count > 100 { readingHistory.removeLast(readingHistory.count - 100) }
        SharedState.defaults.set(readingHistory, forKey: SharedState.Key.affirmationHistory)
    }

    func clear() {
        storage.clear()
        savedCustom = []
        deletedBuiltIns = []
        favorites = []
        readingHistory = []
        selectedTopics = []
        SharedState.defaults.set([], forKey: SharedState.Key.affirmationFavorites)
        SharedState.defaults.set([], forKey: SharedState.Key.affirmationHistory)
        Affirmations.selectedTopics = []
        SharedState.defaults.removeObject(forKey: SharedState.Key.affirmationFeedFocuses)
        SharedState.defaults.removeObject(forKey: SharedState.Key.affirmationReminderFocuses)
        SharedState.defaults.removeObject(forKey: SharedState.Key.affirmationWidgetFocuses)
        SharedState.defaults.removeObject(forKey: SharedState.Key.affirmationReminderTimes)
        SharedState.defaults.removeObject(forKey: SharedState.Key.affirmationReminderWeekdays)
        SharedState.defaults.removeObject(forKey: SharedState.Key.affirmationMinutes)
        SharedState.defaults.set(false, forKey: "affirmationNudgeOn")
        WidgetCenter.shared.reloadAllTimelines()
        AffirmationNudge.reset()
    }

    private func refreshDelivery() {
        WidgetCenter.shared.reloadAllTimelines()
        AffirmationNudge.schedule()
    }

    private func normalizedFocuses(_ values: [String]) -> [String] {
        let valid = Set(availableLibrary.map(\.title) + (savedCustom.isEmpty ? [] : ["Your own"]))
        var seen = Set<String>()
        return values.filter { valid.contains($0) && seen.insert($0).inserted }
    }

    /// Carry existing topic choices forward while splitting dataset categories that used to share
    /// a single app topic.
    private func migrateTopicNames(_ values: [String]) -> [String] {
        var migrated: [String] = []
        for value in values {
            let replacements: [String]
            switch value {
            case "Self-worth": replacements = ["Self-esteem"]
            case "Hard days": replacements = ["Safety"]
            case "Intention": replacements = ["Focus"]
            case "Confidence": replacements = ["Confidence", "Success"]
            default: replacements = [value]
            }
            for replacement in replacements where !migrated.contains(replacement) {
                migrated.append(replacement)
            }
        }
        return migrated
    }

    /// Today's line from the shared topic selection, used on Home and throughout delivery.
    func today(premium: Bool) -> String {
        Affirmations.dailyLine(premium: premium)
    }
}
