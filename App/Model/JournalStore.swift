import Foundation
import SwiftData
import Observation

/// The app's single source of truth for morning pages. Wraps a SwiftData `ModelContext`,
/// derives the streak / week strip / mood distribution the screens read, and — on save —
/// bridges completion into the app group (`SharedState`) and lifts the Screen Time shield so
/// the DeviceActivity extensions stay in sync.
@MainActor
@Observable
final class JournalStore {
    private let context: ModelContext
    private(set) var entries: [Entry] = []       // newest first

    init(context: ModelContext) {
        self.context = context
        reload()
    }

    func reload() {
        let desc = FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        entries = (try? context.fetch(desc)) ?? []
    }

    // MARK: Today
    var todayKey: String { SharedState.dayKey() }
    var todayEntry: Entry? { entries.first { $0.dayKey == todayKey } }
    var ritualDoneToday: Bool { todayEntry != nil }

    func entry(for key: String) -> Entry? { entries.first { $0.dayKey == key } }

    // MARK: Aggregate stats
    var totalMornings: Int { entries.count }
    var recent: [Entry] { Array(entries.prefix(3)) }

    /// Current run of consecutive days ending today (or yesterday, if today isn't done yet).
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

    /// Longest consecutive run in the whole history.
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

    /// Count of pages per mood, index 0…4.
    var distribution: [Int] {
        var c = [0, 0, 0, 0, 0]
        for e in entries where (0...4).contains(e.moodRaw) { c[e.moodRaw] += 1 }
        return c
    }

    // MARK: Week strip (last 7 days, oldest → today)
    struct DayCell: Identifiable {
        let id: String
        let date: Date
        let letter: String        // single-letter weekday
        let entry: Entry?
        let isToday: Bool
        var filled: Bool { entry != nil }
    }

    var weekStrip: [DayCell] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().map { off in
            let d = cal.date(byAdding: .day, value: -off, to: today) ?? today
            let key = SharedState.dayKey(for: d)
            return DayCell(id: key, date: d, letter: Self.weekdayLetter(d),
                           entry: entry(for: key), isToday: off == 0)
        }
    }

    // MARK: Calendar
    func entries(inYear year: Int, month: Int) -> [Entry] {
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
    func saveRitual(mood: Int, journal: String, gratitudes: [String], prompt: String) -> Entry {
        let key = todayKey
        let cal = Calendar.current
        let trimmedJournal = journal.trimmingCharacters(in: .whitespacesAndNewlines)
        let grats = gratitudes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        let entry: Entry
        if let existing = todayEntry {
            entry = existing
        } else {
            entry = Entry(dayKey: key, date: cal.startOfDay(for: Date()),
                          mood: mood, journal: "", gratitudes: [], prompt: prompt)
            context.insert(entry)
        }
        entry.moodRaw = mood
        entry.journal = trimmedJournal.isEmpty ? AppContent.emptyJournalFallback : trimmedJournal
        entry.gratitudes = grats
        entry.prompt = prompt
        entry.createdAt = Date()

        try? context.save()
        reload()

        // Bridge to the extensions: mark done, publish streak, and lift the shield now.
        SharedState.markRitualComplete(mood: String(mood))
        SharedState.streak = streak
        Shielding.clear()
        return entry
    }

    func delete(_ entry: Entry) {
        context.delete(entry)
        try? context.save()
        reload()
    }

    /// Erase everything and return the user to onboarding (the caller also wipes the Screen Time
    /// selection). Resets journal, streak, mood, the onboarding flag, and the morning nudge.
    func deleteAll() {
        for e in entries { context.delete(e) }
        try? context.save()
        reload()
        SharedState.lastRitualDay = nil
        SharedState.streak = 0
        SharedState.todayMoodKey = nil
        SharedState.onboardingComplete = false
        MorningNudge.cancel()
        Shielding.clear()
    }

    // MARK: Backup / restore (JSON, saved via the Files/iCloud picker)

    func makeBackupData() -> Data {
        let snaps = entries.map {
            EntrySnapshot(dayKey: $0.dayKey, date: $0.date, moodRaw: $0.moodRaw,
                          journal: $0.journal, gratitudes: $0.gratitudes, prompt: $0.prompt, createdAt: $0.createdAt)
        }
        return (try? JSONEncoder().encode(BackupPayload(exportedAt: Date(), entries: snaps))) ?? Data()
    }

    /// Merge a backup file into the store (upsert by day). Existing days are updated in place.
    func restore(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(BackupPayload.self, from: data) else { return }
        for snap in payload.entries {
            if let e = entry(for: snap.dayKey) {
                e.moodRaw = snap.moodRaw; e.journal = snap.journal
                e.gratitudes = snap.gratitudes; e.prompt = snap.prompt
            } else {
                context.insert(Entry(dayKey: snap.dayKey, date: snap.date, mood: snap.moodRaw,
                                     journal: snap.journal, gratitudes: snap.gratitudes,
                                     prompt: snap.prompt, createdAt: snap.createdAt))
            }
        }
        try? context.save()
        reload()
    }

    // MARK: Helpers
    private static let letterFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEEE"; return f     // narrow weekday, e.g. "M"
    }()
    static func weekdayLetter(_ d: Date) -> String { letterFmt.string(from: d) }
}
