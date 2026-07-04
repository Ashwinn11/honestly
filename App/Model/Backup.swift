import Foundation

/// A single entry serialized for the backup payload (mirrors the production fields; `JournalEntry`
/// isn't itself Codable).
struct EntrySnapshot: Codable {
    var id: String
    var content: String
    var mood: String
    var gratitude: String
    var wordCount: Int
    var createdAt: Date
    var intention: String
    var tasks: String
}

/// The JSON payload stored in the `JournalBackup` CloudKit record's `payload` (BYTES) field.
struct BackupPayload: Codable {
    var version = 1
    var exportedAt: Date
    var entries: [EntrySnapshot]
}
