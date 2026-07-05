import Foundation
import SwiftData

/// One morning page. **Exactly matches the live production Core Data model** (verified by decoding a
/// real `default.store` entry), so the new SwiftData app *adopts* the existing store with zero
/// migration — every local entry loads, and CloudKit sync continues from the store's own state.
/// Six fields only, `id` is a `UUID`, `mood` is a Capitalized label ("Sad"). No `intention`/`tasks`.
@Model
final class JournalEntry {
    var content: String = ""       // the journal text
    var gratitude: String = ""     // one free-text string (old = 1 note; redesign packs its 5, newline-joined)
    var mood: String = ""          // Capitalized label, e.g. "Sad"
    var wordCount: Int = 0
    var createdAt: Date = Date()
    var id: UUID = UUID()

    init(content: String, gratitude: String, mood: String, wordCount: Int,
         createdAt: Date = Date(), id: UUID = UUID()) {
        self.content = content
        self.gratitude = gratitude
        self.mood = mood
        self.wordCount = wordCount
        self.createdAt = createdAt
        self.id = id
    }

    // MARK: - UI bridges (keep the screens reading the same shape)
    var journal: String { content }
    var date: Date { createdAt }
    var dayKey: String { SharedState.dayKey(for: createdAt) }
    var moodValue: Mood { Mood(stored: mood) }
    var moodRaw: Int { moodValue.rawValue }
    var gratitudes: [String] { JournalEntry.unpackGratitude(gratitude) }
    var gratitudeCount: Int { gratitudes.count }

    // MARK: - Encoding helpers
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
    /// Map a stored/production mood string to a face. Tolerant: a number `0–4` or a label
    /// (production stores Capitalized, e.g. "Sad"); unknown → neutral face, original string kept.
    init(stored raw: String) {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let n = Int(t), let m = Mood(rawValue: n) { self = m; return }
        switch t {
        case "happy":                         self = .happy
        case "confused", "okay", "ok", "meh": self = .confused
        case "sad":                           self = .sad
        case "awful", "terrible", "bad":      self = .awful
        case "cry", "crying":                 self = .cry
        default:                              self = .sad
        }
    }
    /// The string written to `mood` — the Capitalized label, matching production ("Sad").
    var storageKey: String { label }
}
