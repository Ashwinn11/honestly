import Foundation
import SwiftData

/// One morning page. Originally matched the live production Core Data model field-for-field so
/// the SwiftData app could adopt the existing store with zero migration. One deliberate
/// divergence since: `affirmationsRaw` (production's single "gratitude" note, later repurposed to
/// pack 5 affirmations) no longer preserves that column across the schema change — affirmations
/// only matter for the day they're written (Home, notifications, the widget); losing one day's
/// worth at the moment of an update isn't worth carrying the legacy name forever.
@Model
final class JournalEntry {
    var content: String = ""       // the journal text
    var affirmationsRaw: String = ""   // 5 affirmations, newline-joined — see `affirmations` below
    var mood: String = ""          // Capitalized label, e.g. "Sad"
    var wordCount: Int = 0
    var createdAt: Date = Date()
    var id: UUID = UUID()

    // Added post-production — both default so legacy CloudKit records without them decode cleanly.
    @Attribute(.externalStorage) var richContent: Data? = nil   // RTFD blob: formatted text + inline images
    var tags: [String] = []

    init(content: String, affirmationsRaw: String, mood: String, wordCount: Int,
         createdAt: Date = Date(), id: UUID = UUID(), richContent: Data? = nil, tags: [String] = []) {
        self.content = content
        self.affirmationsRaw = affirmationsRaw
        self.mood = mood
        self.wordCount = wordCount
        self.createdAt = createdAt
        self.id = id
        self.richContent = richContent
        self.tags = tags
    }

    // MARK: - UI bridges (keep the screens reading the same shape)
    var journal: String { content }
    var date: Date { createdAt }
    var dayKey: String { SharedState.dayKey(for: createdAt) }
    var moodValue: Mood { Mood(stored: mood) }
    var moodRaw: Int { moodValue.rawValue }
    var affirmations: [String] { JournalEntry.unpackAffirmations(affirmationsRaw) }
    var affirmationCount: Int { affirmations.count }

    // MARK: - Encoding helpers
    static func unpackAffirmations(_ s: String) -> [String] {
        s.split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    static func packAffirmations(_ items: [String]) -> String {
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
