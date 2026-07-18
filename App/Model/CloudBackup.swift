import Foundation
import CloudKit

/// Manual iCloud snapshot backup — the *only* thing in this app that touches iCloud, and only
/// when the user taps "Back up to iCloud" in Profile. Wire-compatible with the **live production
/// app**: same fixed record (`JournalBackup`/`morning-journal-backup`, `payload` BYTES ·
/// `entryCount` INT64 · `backedUpAt` TIMESTAMP) in the private database's default zone, plus one
/// field the production app never wrote — `richContentBundle`, a single `CKAsset` holding every
/// entry's formatting/inline images, keyed by entry id. One record (not one per entry) means no
/// querying/pagination, and the old app just ignores a field it doesn't recognize.
///
/// `richContentBundle` is a **new** field: CloudKit only lets a client create schema against the
/// *Development* environment — this app's Production schema is deploy-only, via the CloudKit
/// Dashboard's "Deploy Schema Changes to Production". Until that one-time deploy happens,
/// `upload` fails on that field specifically (same class of error the old automatic-sync path hit
/// on `affirmationsRaw`). Restore is unaffected either way — reading a record never requires the
/// field to exist first, so old backups (or backups from before this field existed) decode fine
/// with `richContent` just empty.
enum CloudBackup {
    private static let container = CKContainer(identifier: AppConfig.iCloudContainerID)
    private static var db: CKDatabase { container.privateCloudDatabase }
    private static let recordType = "JournalBackup"
    private static let recordID = CKRecord.ID(recordName: "morning-journal-backup")  // must match production

    /// Every entry's formatting/images, keyed by entry id, packed into one blob so it travels as
    /// a single `CKAsset` instead of one per entry.
    private struct RichContentBundle: Codable {
        var items: [UUID: Data]
    }

    static func upload(entries: [EntrySnapshot]) async throws {
        let record: CKRecord
        if let existing = try? await db.record(for: recordID) { record = existing }
        else { record = CKRecord(recordType: recordType, recordID: recordID) }

        // Same bare-array shape the production app reads/writes — richContent is stripped before
        // encoding so a no-images backup stays exactly the size it always was, and old builds
        // decoding this JSON never see a field they don't expect.
        let bare = entries.map {
            EntrySnapshot(id: $0.id, content: $0.content, mood: $0.mood, wordCount: $0.wordCount,
                          createdAt: $0.createdAt, tags: $0.tags)
        }
        record["payload"] = ((try? JSONEncoder().encode(bare)) ?? Data()) as CKRecordValue
        record["entryCount"] = entries.count as CKRecordValue
        record["backedUpAt"] = Date() as CKRecordValue

        let richItems = Dictionary(uniqueKeysWithValues: entries.compactMap { e in
            e.richContent.map { (e.id, $0) }
        })
        var tempURL: URL?
        defer { if let tempURL { try? FileManager.default.removeItem(at: tempURL) } }

        if richItems.isEmpty {
            record["richContentBundle"] = nil   // clears a stale asset if every image was since removed
        } else {
            let bundleData = try PropertyListEncoder().encode(RichContentBundle(items: richItems))
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".richbundle")
            try bundleData.write(to: url)
            tempURL = url
            record["richContentBundle"] = CKAsset(fileURL: url)
        }

        try await db.save(record)
    }

    /// The latest backup's bare payload plus any rich content, keyed by entry id. `nil` if no
    /// backup exists at all.
    static func latestPayload() async throws -> (payload: Data, richContent: [UUID: Data])? {
        let record: CKRecord?
        if let r = try? await db.record(for: recordID) {
            record = r
        } else {
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "backedUpAt", ascending: false)]
            record = (try? await db.records(matching: query, resultsLimit: 3))?
                .matchResults
                .compactMap { try? $0.1.get() }
                .first
        }
        guard let record, let payload = record["payload"] as? Data else { return nil }

        var richContent: [UUID: Data] = [:]
        if let asset = record["richContentBundle"] as? CKAsset, let url = asset.fileURL,
           let bundleData = try? Data(contentsOf: url),
           let bundle = try? PropertyListDecoder().decode(RichContentBundle.self, from: bundleData) {
            richContent = bundle.items
        }
        return (payload, richContent)
    }
}
