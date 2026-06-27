import Foundation
import CloudKit

/// Manual full-snapshot backup on top of Core Data sync.
/// Writes a native `JournalBackup` CKRecord (backedUpAt / entryCount / payload)
/// to the private database of `iCloud.com.morning-journal.app`.
struct JournalBackup: Codable {
    let backedUpAt: Date
    let entryCount: Int
    let entries: [JournalEntry]
}

final class BackupManager {
    static let shared = BackupManager()

    private let recordType = "JournalBackup"
    private let database = CKContainer(identifier: PersistenceController.cloudKitContainerID).privateCloudDatabase

    /// Encode all entries into a single backup record and upload it.
    func backUp(entries: [JournalEntry]) async throws {
        let snapshot = JournalBackup(backedUpAt: Date(), entryCount: entries.count, entries: entries)
        let payload = try JSONEncoder().encode(snapshot)

        let record = CKRecord(recordType: recordType)
        record["backedUpAt"] = snapshot.backedUpAt as CKRecordValue
        record["entryCount"] = snapshot.entryCount as CKRecordValue
        record["payload"]    = payload as CKRecordValue

        try await database.save(record)
    }

    /// Fetch the most recent backup snapshot, if any.
    func latestBackup() async throws -> JournalBackup? {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "backedUpAt", ascending: false)]

        let result = try await database.records(matching: query, resultsLimit: 1)
        guard let (_, recordResult) = result.matchResults.first,
              let record = try? recordResult.get(),
              let payload = record["payload"] as? Data else { return nil }
        return try JSONDecoder().decode(JournalBackup.self, from: payload)
    }
}
