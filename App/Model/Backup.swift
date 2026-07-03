import SwiftUI
import UniformTypeIdentifiers

/// A single entry serialized for backup (SwiftData `Entry` is not itself Codable).
struct EntrySnapshot: Codable {
    var dayKey: String
    var date: Date
    var moodRaw: Int
    var journal: String
    var gratitudes: [String]
    var prompt: String
    var createdAt: Date
}

/// The JSON payload written to / read from a `.json` backup file (Files or iCloud Drive).
struct BackupPayload: Codable {
    var version = 1
    var exportedAt: Date
    var entries: [EntrySnapshot]
}

/// Wraps the backup JSON so SwiftUI's `.fileExporter` can save it through the system picker.
struct BackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
