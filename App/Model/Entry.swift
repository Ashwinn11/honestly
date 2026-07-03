import Foundation
import SwiftData

/// One morning page. Stored in SwiftData; every attribute has a default and there are no unique
/// constraints, so the same model is CloudKit-syncable when iCloud is enabled. Uniqueness per day
/// is enforced by `JournalStore` (it fetches today's entry before inserting).
@Model
final class Entry {
    var dayKey: String = ""            // "yyyy-MM-dd" in the user's calendar — the lookup key
    var date: Date = Date()            // start-of-day for grouping / calendar placement
    var moodRaw: Int = 2               // 0…4 → Mood
    var journal: String = ""
    var gratitudes: [String] = []
    var prompt: String = ""
    var createdAt: Date = Date()

    init(dayKey: String, date: Date, mood: Int, journal: String,
         gratitudes: [String], prompt: String, createdAt: Date = Date()) {
        self.dayKey = dayKey
        self.date = date
        self.moodRaw = mood
        self.journal = journal
        self.gratitudes = gratitudes
        self.prompt = prompt
        self.createdAt = createdAt
    }

    var mood: Mood { Mood(rawValue: moodRaw) ?? .sad }
    var gratitudeCount: Int { gratitudes.count }
}
