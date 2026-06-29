import SwiftUI

enum Mood: String, CaseIterable, Codable, Identifiable {
    case happy    = "Happy"
    case confused = "Confused"
    case sad      = "Sad"
    case awful    = "Awful"
    case cry      = "Cry"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .happy:    return Theme.happy
        case .confused: return Theme.confused
        case .sad:      return Theme.sad
        case .awful:    return Theme.awful
        case .cry:      return Theme.cry
        }
    }

    /// Localized name for display. `rawValue` stays English — it's the Codable
    /// storage key — so we look it up as a catalog key instead.
    var displayName: String { L(rawValue) }

    /// Lowercase phrasing for the ritual header ("feeling awful").
    var feelingLabel: String {
        String(format: L("feeling %@"), displayName.lowercased())
    }
}
