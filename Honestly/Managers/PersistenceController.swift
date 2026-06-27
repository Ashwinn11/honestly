import CoreData
import CloudKit

/// Core Data stack backed by CloudKit mirroring.
/// Entity `JournalEntry` mirrors to record type `CD_JournalEntry` in the
/// `iCloud.com.morning-journal.app` container — matching existing synced data.
struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    static let cloudKitContainerID = "iCloud.com.morning-journal.app"
    private static let storeName = "Honestly"

    /// The ORIGINAL app's store lives here (verified on-disk):
    ///   <appGroup>/Library/Application Support/default.store
    /// We must reuse this exact URL so existing users' entries open in place
    /// (lightweight migration), not get abandoned in a fresh store.
    private static let storeFileName = "default.store"

    init(inMemory: Bool = false, cloudSyncEnabled: Bool = PersistenceController.cloudSyncDefault) {
        container = NSPersistentCloudKitContainer(name: Self.storeName)

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Missing persistent store description")
        }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        } else if let groupURL = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier) {
            let supportDir = groupURL.appendingPathComponent("Library/Application Support", isDirectory: true)
            try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
            description.url = supportDir.appendingPathComponent(Self.storeFileName)
        }

        // Required for CloudKit mirroring.
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // Toggle CloudKit on/off based on the user's iCloud Sync setting.
        if cloudSyncEnabled && !inMemory {
            description.cloudKitContainerOptions =
                NSPersistentCloudKitContainerOptions(containerIdentifier: Self.cloudKitContainerID)
        } else {
            description.cloudKitContainerOptions = nil
        }

        container.loadPersistentStores { _, error in
            if let error {
                // Non-fatal: surface for debugging but keep the app usable locally.
                print("Core Data store load error: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    static var cloudSyncDefault: Bool {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
        // Default ON unless the user explicitly turned it off.
        if defaults?.object(forKey: AppConstants.keyCloudSyncEnabled) == nil { return true }
        return defaults?.bool(forKey: AppConstants.keyCloudSyncEnabled) ?? true
    }
}
