import Foundation

/// Reading is separate from editing: this snapshot never writes to the daily rotation.
struct AffirmationReadingContent {
    let lines: [String]
    let initialIndex: Int

    init(rotation: [String], today: String) {
        var seen = Set<String>()
        lines = rotation.filter { !$0.isEmpty && seen.insert($0).inserted }
        initialIndex = lines.firstIndex(of: today) ?? 0
    }
}
