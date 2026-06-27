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

    var displayName: String { rawValue }

    /// Lowercase phrasing for the ritual header ("feeling awful").
    var feelingLabel: String { "feeling \(rawValue.lowercased())" }
}
