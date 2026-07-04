import Foundation
import SwiftData

/// One morning page. **Maps 1:1 onto the live production CloudKit schema** (`CD_JournalEntry`):
/// same entity name and attribute names, so the redesign reads/writes existing users' data
/// without a schema mismatch. Every attribute has a default and there are no unique constraints —
/// required for CloudKit. The UI talks to this through the computed bridges at the bottom.
@Model
final class JournalEntry {
    var id: String = UUID().uuidString   // CD_id
    var content: String = ""             // CD_content   — the journal text
    var mood: String = ""                // CD_mood      — stored mood key ("happy"…"cry")
    var gratitude: String = ""           // CD_gratitude — one string (old: single note; new: 5, newline-joined)
    var wordCount: Int = 0               // CD_wordCount
    var createdAt: Date = Date()         // CD_createdAt
    var intention: String = ""           // CD_intention — always empty in prod → reused for the daily prompt
    var tasks: String = ""               // CD_tasks     — always empty in prod → left empty

    init(id: String = UUID().uuidString, content: String, mood: String, gratitude: String,
         wordCount: Int, createdAt: Date = Date(), intention: String = "", tasks: String = "") {
        self.id = id
        self.content = content
        self.mood = mood
        self.gratitude = gratitude
        self.wordCount = wordCount
        self.createdAt = createdAt
        self.intention = intention
        self.tasks = tasks
    }

    // MARK: - UI bridges (so the screens read the same shape as before)
    var journal: String { content }
    var prompt: String { get { intention } set { intention = newValue } }   // stored in CD_intention
    var date: Date { createdAt }
    var dayKey: String { SharedState.dayKey(for: createdAt) }
    var moodValue: Mood { Mood(stored: mood) }
    var moodRaw: Int { moodValue.rawValue }
    var gratitudes: [String] { JournalEntry.unpackGratitude(gratitude) }
    var gratitudeCount: Int { gratitudes.count }

    // MARK: - Encoding helpers (the pack/unpack the whole app shares)
    static func unpackGratitude(_ s: String) -> [String] {
        s.split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    static func packGratitude(_ items: [String]) -> String {
        items.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: "\n")
    }
    static func wordCount(of text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}

extension Mood {
    /// Map a stored/production mood string to a face. Tolerant: a number `0–4`, or a key/label —
    /// including the old **"okay"** which the redesign shows as **"confused"** (same slot). Anything
    /// unrecognized falls back to a neutral face; the caller preserves the original string.
    init(stored raw: String) {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let n = Int(t), let m = Mood(rawValue: n) { self = m; return }
        switch t {
        case "happy":                     self = .happy
        case "okay", "ok", "confused", "meh": self = .confused
        case "sad":                       self = .sad
        case "awful", "terrible", "bad":  self = .awful
        case "cry", "crying":             self = .cry
        default:                          self = .sad
        }
    }
    /// The canonical lowercase key the redesign writes for each face.
    var storageKey: String { ["happy", "confused", "sad", "awful", "cry"][rawValue] }
}
