import Foundation
import CoreData
import Combine

/// Day-grouped section for the Journal tab list.
struct JournalDay: Identifiable {
    var id: String { key }
    let key: String          // yyyy-MM-dd
    let date: Date
    let entries: [JournalEntry]
}

/// Owns journal data. Backed by Core Data + CloudKit; mirrors completion flags
/// and widget snapshot to the App Group UserDefaults for extensions/widgets.
class JournalManager: ObservableObject {
    /// Word count at/above which the ritual's "next" button switches to its orange styling.
    static let encouragedWordCount = 10

    @Published var sproutCount: Int = 0
    @Published var isCompletedToday: Bool = false
    @Published var entries: [JournalEntry] = []

    private let context: NSManagedObjectContext
    private let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
    private var cancellables = Set<AnyCancellable>()

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        isCompletedToday = AppConstants.isJournalCompleted(in: defaults)
        reload()

        // Refresh when CloudKit / another context merges changes.
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
    }

    var currentStage: PlantStage { PlantStage.stage(for: sproutCount) }

    // MARK: - Load

    func reload() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "JournalEntry")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let objects = (try? context.fetch(request)) ?? []
        entries = objects.compactMap { Self.map($0) }
        sproutCount = entries.count
        defaults?.set(sproutCount, forKey: AppConstants.keySproutCount)
        isCompletedToday = AppConstants.isJournalCompleted(in: defaults)
    }

    /// Map a `CDJournalEntry` managed object → value struct.
    private static func map(_ obj: NSManagedObject) -> JournalEntry? {
        guard let createdAt = obj.value(forKey: "createdAt") as? Date else { return nil }
        let moodRaw = obj.value(forKey: "mood") as? String ?? Mood.confused.rawValue
        let id = obj.value(forKey: "id") as? UUID
        return JournalEntry(
            id: id ?? UUID(),
            date: createdAt,
            mood: Mood(rawValue: moodRaw) ?? .confused,
            content: obj.value(forKey: "content") as? String ?? "",
            gratitude: obj.value(forKey: "gratitude") as? String ?? "",
            wordCount: Int(obj.value(forKey: "wordCount") as? Int64 ?? 0)
        )
    }

    // MARK: - Completion

    func markCompleted(mood: Mood, content: String, gratitude: String) {
        let now = Date()
        let wordCount = content.split { $0 == " " || $0 == "\n" }.count

        // One entry per day: reuse today's managed object if it already exists.
        let obj = todayManagedObject() ?? {
            let new = NSEntityDescription.insertNewObject(forEntityName: "JournalEntry", into: context)
            new.setValue(UUID(), forKey: "id")
            return new
        }()
        obj.setValue(content, forKey: "content")
        obj.setValue(gratitude, forKey: "gratitude")
        obj.setValue(mood.rawValue, forKey: "mood")
        obj.setValue(now, forKey: "createdAt")
        obj.setValue(Int64(wordCount), forKey: "wordCount")
        try? context.save()

        // Completion flags + widget snapshot (read by extensions / widgets).
        defaults?.set(true, forKey: AppConstants.keyTodayCompleted)
        defaults?.set(now, forKey: AppConstants.keyLastCompletionDate)
        defaults?.set(mood.rawValue, forKey: AppConstants.widgetKeyMood)
        defaults?.set(content, forKey: AppConstants.widgetKeyJournal)
        defaults?.set(gratitude, forKey: AppConstants.widgetKeyGratitude)
        defaults?.set(now, forKey: AppConstants.widgetKeyDate)

        reload()
        isCompletedToday = true
    }

    func resetForNewDay() {
        guard !AppConstants.isJournalCompleted(in: defaults) else { return }
        defaults?.set(false, forKey: AppConstants.keyTodayCompleted)
        isCompletedToday = false
    }

    /// The managed object for today's entry, if one exists (enforces one-per-day).
    private func todayManagedObject() -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "JournalEntry")
        let objs = (try? context.fetch(request)) ?? []
        return objs.first { obj in
            guard let d = obj.value(forKey: "createdAt") as? Date else { return false }
            return Calendar.current.isDateInToday(d)
        }
    }

    // MARK: - Calendar / lookup

    func mood(on date: Date) -> Mood? { entry(for: date)?.mood }

    func entry(for date: Date) -> JournalEntry? {
        let key = JournalEntry.dayFormatter.string(from: date)
        return entries.first { $0.dayKey == key }
    }

    func moods(inMonth date: Date) -> [String: Mood] {
        let cal = Calendar.current
        var result: [String: Mood] = [:]
        for e in entries where cal.isDate(e.date, equalTo: date, toGranularity: .month) {
            result[e.dayKey] = e.mood
        }
        return result
    }

    var groupedByDay: [JournalDay] {
        Dictionary(grouping: entries) { $0.dayKey }
            .map { key, items in
                JournalDay(key: key, date: items.first?.date ?? Date(),
                           entries: items.sorted { $0.date > $1.date })
            }
            .sorted { $0.date > $1.date }
    }

    func search(_ query: String) -> [JournalEntry] {
        guard !query.isEmpty else { return entries }
        let q = query.lowercased()
        return entries.filter {
            $0.content.lowercased().contains(q) || $0.gratitude.lowercased().contains(q)
        }
    }

    // MARK: - Data

    /// Delete a single entry (long-press in the journal). Deletes individually so
    /// CloudKit mirrors the removal. If it was today's, re-open today's ritual.
    func delete(_ entry: JournalEntry) {
        let request = NSFetchRequest<NSManagedObject>(entityName: "JournalEntry")
        let objs = (try? context.fetch(request)) ?? []
        for o in objs where (o.value(forKey: "id") as? UUID) == entry.id {
            context.delete(o)
        }
        try? context.save()
        if Calendar.current.isDateInToday(entry.date) {
            defaults?.set(false, forKey: AppConstants.keyTodayCompleted)
        }
        reload()
    }

    /// Insert backed-up entries from iCloud. Dedupe by **day** (and id) so a day
    /// that already has a local entry never gets a duplicate — e.g. restoring an
    /// old backup after you deleted + re-journaled the same day keeps just one.
    func restore(from backup: [JournalEntry]) {
        let existingIDs = Set(entries.map { $0.id })
        var seenDays = Set(entries.map { $0.dayKey })   // days already occupied
        for e in backup where !existingIDs.contains(e.id) && !seenDays.contains(e.dayKey) {
            seenDays.insert(e.dayKey)
            let obj = NSEntityDescription.insertNewObject(forEntityName: "JournalEntry", into: context)
            obj.setValue(e.id, forKey: "id")
            obj.setValue(e.content, forKey: "content")
            obj.setValue(e.gratitude, forKey: "gratitude")
            obj.setValue(e.mood.rawValue, forKey: "mood")
            obj.setValue(e.date, forKey: "createdAt")
            obj.setValue(Int64(e.wordCount), forKey: "wordCount")
        }
        try? context.save()
        reload()
    }

    /// Full wipe — removes every entry AND resets onboarding so the user lands
    /// back on the welcome flow. Deletes objects individually so CloudKit mirrors it.
    func deleteAllData() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "JournalEntry")
        let objs = (try? context.fetch(request)) ?? []
        objs.forEach(context.delete)
        try? context.save()

        [AppConstants.keyTodayCompleted, AppConstants.keyLastCompletionDate,
         AppConstants.keySproutCount, AppConstants.widgetKeyMood, AppConstants.widgetKeyJournal,
         AppConstants.widgetKeyGratitude, AppConstants.widgetKeyDate,
         AppConstants.keyHasCompletedOnboarding, AppConstants.keyHasSeenPaywall,
         AppConstants.keyUserOutcome, AppConstants.keyUserName, AppConstants.keyScrollMinutes]
            .forEach { defaults?.removeObject(forKey: $0) }
        defaults?.synchronize()

        reload()
        isCompletedToday = false
    }
}
