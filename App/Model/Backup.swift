import Foundation

/// A single entry serialized for the backup payload (mirrors the production fields; `JournalEntry`
/// isn't itself Codable).
///
/// Deliberately does **not** carry affirmations — pages don't hold them anymore (they're a picked
/// rotation in the app group; see `Affirmations`), and the legacy `JournalEntry.affirmationsRaw`
/// on older pages is never displayed, so it's not worth the payload weight here.
struct EntrySnapshot: Codable {
    var id: UUID
    var content: String
    var mood: String
    var wordCount: Int
    var createdAt: Date
    var tags: [String] = []
    var themeID: String = ""     // PageTheme raw value; "" (or a missing key, on old backups) → .paper
    // Formatting + inline images (RTFD blob). Only ever populated on the current per-entry CKAsset
    // backup format — the legacy single-blob production format never carried this, so it decodes
    // to nil there, same as a missing `tags` key on an old backup.
    var richContent: Data? = nil
    var prompt: String = ""      // the question the page answered; missing on older backups

    // Manual init(from:) so older backups (written before `tags`/`richContent`/`themeID` existed)
    // still decode — a plain default value on the property doesn't help here, since synthesized
    // Codable would otherwise require the key to be present. Older backups carrying
    // now-unrecognized keys (e.g. a legacy affirmations field) decode fine too — Codable silently
    // ignores keys a struct doesn't declare.
    enum CodingKeys: String, CodingKey { case id, content, mood, wordCount, createdAt, tags, themeID, richContent, prompt }

    init(id: UUID, content: String, mood: String, wordCount: Int, createdAt: Date, tags: [String] = [],
         themeID: String = "", richContent: Data? = nil, prompt: String = "") {
        self.id = id
        self.content = content
        self.mood = mood
        self.wordCount = wordCount
        self.createdAt = createdAt
        self.tags = tags
        self.themeID = themeID
        self.richContent = richContent
        self.prompt = prompt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        content = try c.decode(String.self, forKey: .content)
        mood = try c.decode(String.self, forKey: .mood)
        wordCount = try c.decode(Int.self, forKey: .wordCount)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        themeID = try c.decodeIfPresent(String.self, forKey: .themeID) ?? ""
        richContent = try c.decodeIfPresent(Data.self, forKey: .richContent)
        prompt = try c.decodeIfPresent(String.self, forKey: .prompt) ?? ""
    }
}

struct BackupPayload: Codable {
    var version = 1
    var exportedAt: Date
    var entries: [EntrySnapshot]
}
