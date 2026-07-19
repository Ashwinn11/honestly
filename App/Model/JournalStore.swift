import Foundation
import SwiftData
import Observation
import WidgetKit

/// The app's single source of truth for morning pages. Wraps a SwiftData `ModelContext`,
/// derives the streak / week strip / mood distribution the screens read, and — on save —
/// bridges completion into the app group (`SharedState`) and lifts the Screen Time shield so
/// the DeviceActivity extensions stay in sync.
@MainActor
@Observable
final class JournalStore {
    private let context: ModelContext
    private(set) var entries: [JournalEntry] = []       // newest first

    init(context: ModelContext) {
        self.context = context
        reload()
    }

    func reload() {
        let desc = FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let all = (try? context.fetch(desc)) ?? []
        var seenDays = Set<String>()
        var kept: [JournalEntry] = []
        var duplicates: [JournalEntry] = []
        for e in all {
            if seenDays.insert(e.dayKey).inserted { kept.append(e) } else { duplicates.append(e) }
        }
        if !duplicates.isEmpty {
            duplicates.forEach(context.delete)
            try? context.save()
        }
        entries = kept
        syncWidgetData()
        healRitualFlag()
    }

    /// The app-group flag (`lastRitualDay`) is what the selection commit and the 04:00 extension
    /// read — but the database is the truth, and the two can diverge (a reinstall keeps app-group
    /// defaults while the store resets, leaving a stale "done today" that silently blocks
    /// re-shielding). Force the flag to match the database on every reload.
    private func healRitualFlag() {
        let done = todayEntry != nil
        guard done != SharedState.ritualCompleted() else { return }
        SharedState.lastRitualDay = done ? todayKey : nil
    }

    /// Keeps the widget's cross-process cache (`SharedState.todayAffirmations`) in step with the
    /// real store on every mutation this triggers from (save, delete, deleteAll, launch) — covers
    /// entries that existed before this cache did, and clears stale data the moment today's entry
    /// is deleted, rather than only ever refreshing it on a fresh save.
    private func syncWidgetData() {
        let today = entries.first { $0.dayKey == SharedState.dayKey() }
        let lines = today?.affirmations ?? []
        guard lines != SharedState.todayAffirmations else { return }   // avoid needless widget reloads
        SharedState.todayAffirmations = lines
        SharedState.todayAffirmationsSetAt = lines.isEmpty ? nil : Date()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Today
    var todayKey: String { SharedState.dayKey() }
    var todayEntry: JournalEntry? { entries.first { $0.dayKey == todayKey } }
    var ritualDoneToday: Bool { todayEntry != nil }

    func entry(for key: String) -> JournalEntry? { entries.first { $0.dayKey == key } }

    // MARK: Aggregate stats
    var totalMornings: Int { entries.count }

    var streak: Int {
        let cal = Calendar.current
        let keys = Set(entries.map(\.dayKey))
        var day = cal.startOfDay(for: Date())
        if !keys.contains(SharedState.dayKey(for: day)) {
            guard let y = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = y
        }
        var count = 0
        while keys.contains(SharedState.dayKey(for: day)) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    var bestStreak: Int {
        let cal = Calendar.current
        let days = entries.map { cal.startOfDay(for: $0.date) }.sorted()
        guard !days.isEmpty else { return 0 }
        var best = 1, run = 1
        for i in 1..<days.count {
            if let prev = cal.date(byAdding: .day, value: 1, to: days[i - 1]),
               cal.isDate(prev, inSameDayAs: days[i]) {
                run += 1
            } else if !cal.isDate(days[i - 1], inSameDayAs: days[i]) {
                run = 1
            }
            best = max(best, run)
        }
        return best
    }

    var distribution: [Int] {
        var c = [0, 0, 0, 0, 0]
        for e in entries where (0...4).contains(e.moodRaw) { c[e.moodRaw] += 1 }
        return c
    }

    // MARK: Week strip (last 7 days, oldest → today)
    struct DayCell: Identifiable {
        let id: String
        let entry: JournalEntry?
    }

    var weekStrip: [DayCell] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().map { off in
            let d = cal.date(byAdding: .day, value: -off, to: today) ?? today
            let key = SharedState.dayKey(for: d)
            return DayCell(id: key, entry: entry(for: key))
        }
    }

    // MARK: Calendar
    func entries(inYear year: Int, month: Int) -> [JournalEntry] {
        let cal = Calendar.current
        return entries.filter {
            let c = cal.dateComponents([.year, .month], from: $0.date)
            return c.year == year && c.month == month
        }
    }

    func monthCount(year: Int, month: Int) -> Int { entries(inYear: year, month: month).count }

    // MARK: Mutations

    /// Create or update today's page, then sync completion out to the app group + shield.
    @discardableResult
    func saveRitual(mood: Int, journal: String, affirmations: [String],
                     richContent: Data? = nil, tags: [String] = [],
                     themeID: String = "", thumbnail: Data? = nil) -> JournalEntry {
        let face = Mood(rawValue: mood) ?? .sad
        let trimmed = journal.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = trimmed.isEmpty ? AppContent.emptyJournalFallback : trimmed
        let packed = JournalEntry.packAffirmations(affirmations)

        let entry: JournalEntry
        if let existing = todayEntry {
            entry = existing
        } else {
            entry = JournalEntry(content: content, affirmationsRaw: packed, mood: face.storageKey,
                                 wordCount: JournalEntry.wordCount(of: content), createdAt: Date())
            context.insert(entry)
        }
        entry.content = content
        entry.affirmationsRaw = packed
        entry.mood = face.storageKey
        entry.wordCount = JournalEntry.wordCount(of: content)
        entry.richContent = richContent
        entry.tags = tags
        entry.themeID = themeID
        entry.thumbnail = thumbnail

        try? context.save()
        reload()

        SharedState.markRitualComplete(mood: face.storageKey)
        SharedState.streak = streak
        Shielding.reconcile()
        AffirmationNudge.scheduleForToday()
        return entry
    }

    /// Edit an already-saved page (any day) from the reader. Content-only: mood, affirmations,
    /// and all the save-ritual side effects (completion flag, streak, shield, notifications) are
    /// morning-ritual concerns and deliberately don't re-fire on an edit.
    @discardableResult
    func update(_ entry: JournalEntry, journal: String, richContent: Data?, tags: [String],
                themeID: String, thumbnail: Data?) -> JournalEntry {
        let trimmed = journal.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.content = trimmed.isEmpty ? AppContent.emptyJournalFallback : trimmed
        entry.wordCount = JournalEntry.wordCount(of: entry.content)
        entry.richContent = richContent
        entry.tags = tags
        entry.themeID = themeID
        entry.thumbnail = thumbnail
        try? context.save()
        reload()
        return entry
    }

    /// Deleting today's page rewinds the day to "not written yet": the completion flag and the
    /// queued echo notifications are cleared before `reload()` so the widget rebuild sees a
    /// consistent state, and the shield comes back if blocking would be active right now —
    /// otherwise the home screen says "your page is waiting" while the apps stay unlocked.
    func delete(_ entry: JournalEntry) {
        let wasToday = entry.dayKey == todayKey
        if wasToday {
            SharedState.lastRitualDay = nil
            SharedState.todayMoodKey = nil
            AffirmationNudge.cancel()
        }
        context.delete(entry)
        try? context.save()
        reload()
        if wasToday { Shielding.reconcile() }
    }

    func deleteAll() {
        for e in entries { context.delete(e) }
        try? context.save()
        reload()
        SharedState.lastRitualDay = nil
        SharedState.streak = 0
        SharedState.todayMoodKey = nil
        SharedState.onboardingComplete = false
        SharedState.weeklyGoal = 5
        AffirmationNudge.cancel()
        Shielding.clear()
    }

    // MARK: iCloud snapshot backup / restore (CloudKit `JournalBackup` record) — the only place
    // this app talks to iCloud; only ever runs from the explicit Profile action, never automatically.

    private func makeSnapshots() -> [EntrySnapshot] {
        entries.map {
            EntrySnapshot(id: $0.id, content: $0.content, mood: $0.mood, wordCount: $0.wordCount,
                          createdAt: $0.createdAt, tags: $0.tags, themeID: $0.themeID,
                          richContent: $0.richContent)
        }
    }

    @discardableResult
    func backupToCloud() async -> Bool {
        do { try await CloudBackup.upload(entries: makeSnapshots()); return true }
        catch { return false }
    }

    func restoreFromCloud() async -> Int? {
        let result: (payload: Data, richContent: [UUID: Data])?
        do { result = try await CloudBackup.latestPayload() } catch { return nil }
        guard let result else { return nil }
        // Tolerant decode: the production format is a bare array; older new-app builds wrote a
        // `{ version, exportedAt, entries }` wrapper — accept either.
        let snaps: [EntrySnapshot]
        if let arr = try? JSONDecoder().decode([EntrySnapshot].self, from: result.payload) {
            snaps = arr
        } else if let payload = try? JSONDecoder().decode(BackupPayload.self, from: result.payload) {
            snaps = payload.entries
        } else {
            return nil
        }
        let existingIds = Set(entries.map(\.id))
        var filledDays = Set(entries.map(\.dayKey))   // days that already have a page — never duplicate
        var added = 0
        for snap in snaps {
            let day = SharedState.dayKey(for: snap.createdAt)
            guard !existingIds.contains(snap.id), !filledDays.contains(day) else { continue }
            // Affirmations aren't carried in the snapshot (see EntrySnapshot's doc comment) —
            // restored entries land with none, same as any entry whose affirmations were never
            // the point of restoring. The History thumbnail isn't carried either — it's derived
            // data, regenerated here from the restored rich content (one decode per entry, once).
            let rich = result.richContent[snap.id]
            let thumbnail = rich.flatMap { NSAttributedString.from(rtfdData: $0)?.firstPhotoThumbnail() }
            context.insert(JournalEntry(content: snap.content, affirmationsRaw: "", mood: snap.mood,
                                        wordCount: snap.wordCount, createdAt: snap.createdAt, id: snap.id,
                                        richContent: rich, tags: snap.tags,
                                        themeID: snap.themeID, thumbnail: thumbnail))
            filledDays.insert(day)
            added += 1
        }
        try? context.save()
        reload()
        return added
    }
}
