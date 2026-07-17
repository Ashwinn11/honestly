import UIKit

/// Encode/decode an `NSAttributedString` (formatted text + inline images) to `Data`, for storing
/// in `JournalEntry.richContent`.
///
/// Uses the `FileWrapper`-based RTFD read/write pair, not the flat-`Data`
/// `NSAttributedString(data:options:documentType:.rtfd)` initializer — that flat-data path is
/// confirmed buggy on iOS and silently drops image attachments, because RTFD-with-images is
/// fundamentally a directory bundle (an RTF text stream alongside image subfiles), not a flat
/// stream. Routing through a real `FileWrapper`, backed by a temp file on decode, is the
/// iOS-safe pattern.
extension NSAttributedString {
    func rtfdData() -> Data? {
        guard length > 0 else { return Data() }
        let range = NSRange(location: 0, length: length)
        guard let wrapper = try? fileWrapper(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]) else {
            return nil
        }
        return wrapper.serializedRepresentation
    }

    static func from(rtfdData data: Data) -> NSAttributedString? {
        guard !data.isEmpty else { return NSAttributedString() }
        guard let wrapper = FileWrapper(serializedRepresentation: data) else { return nil }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let tempURL = tempDir.appendingPathComponent("entry.rtfd", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try wrapper.write(to: tempURL, options: [], originalContentsURL: nil)
            return try NSAttributedString(url: tempURL,
                                          options: [.documentType: NSAttributedString.DocumentType.rtfd],
                                          documentAttributes: nil)
        } catch {
            return nil
        }
    }
}
