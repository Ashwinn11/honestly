import Foundation

/// App-facing value model. Persisted via Core Data (`CDJournalEntry`) and
/// serialized into the CloudKit `JournalBackup` payload.
/// Note: the daily prompt + gratitude question are shown live during the ritual
/// and are NOT stored (matching the original `CD_JournalEntry` schema, where
/// `intention`/`tasks` are deprecated).
struct JournalEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var mood: Mood
    var content: String      // the morning's journal text
    var gratitude: String    // the gratitude note
    var wordCount: Int

    var dayKey: String { JournalEntry.dayFormatter.string(from: date) }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
