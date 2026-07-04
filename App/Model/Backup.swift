import Foundation

/// A single entry serialized for the backup payload (mirrors the production fields; `JournalEntry`
/// isn't itself Codable).
struct EntrySnapshot: Codable {
    var id: UUID
    var content: String
    var mood: String
    var gratitude: String
    var wordCount: Int
    var createdAt: Date
}

struct BackupPayload: Codable {
    var version = 1
    var exportedAt: Date
    var entries: [EntrySnapshot]
}
