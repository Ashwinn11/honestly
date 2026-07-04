import Foundation
import CloudKit

/// Manual iCloud snapshot backup — wire-compatible with the **live production app** so backups
/// round-trip between the old and new versions. Uses the production `JournalBackup` record type
/// (`payload` BYTES · `entryCount` INT64 · `backedUpAt` TIMESTAMP) in the private database's
/// default zone, under the **same record name (`morning-journal-backup`)** the production app uses.
/// Separate from the automatic SwiftData sync; the explicit "back up / restore" on the iCloud row.
enum CloudBackup {
    private static let container = CKContainer(identifier: AppConfig.iCloudContainerID)
    private static var db: CKDatabase { container.privateCloudDatabase }
    private static let recordType = "JournalBackup"
    private static let recordID = CKRecord.ID(recordName: "morning-journal-backup")  // must match production

    /// Write (or overwrite) the single backup record.
    static func upload(payload: Data, entryCount: Int) async throws {
        let record: CKRecord
        if let existing = try? await db.record(for: recordID) {
            record = existing
        } else {
            record = CKRecord(recordType: recordType, recordID: recordID)
        }
        record["payload"] = payload as CKRecordValue
        record["entryCount"] = entryCount as CKRecordValue
        record["backedUpAt"] = Date() as CKRecordValue
        try await db.save(record)
    }

    /// The most recent backup's payload, or nil if there is none.
    static func latestPayload() async throws -> Data? {
        // Primary path: our fixed record.
        if let record = try? await db.record(for: recordID), let data = record["payload"] as? Data {
            return data
        }
        // Best-effort fallback: any JournalBackup, newest first (e.g. one the old app wrote).
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "backedUpAt", ascending: false)]
        if let result = try? await db.records(matching: query, resultsLimit: 3) {
            for (_, res) in result.matchResults {
                if case .success(let record) = res, let data = record["payload"] as? Data { return data }
            }
        }
        return nil
    }
}
