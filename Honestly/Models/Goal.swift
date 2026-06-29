import SwiftUI

enum Goal: String, CaseIterable, Codable, Identifiable {
    case clarity = "Clarity"
    case peace   = "Peace"
    case focus   = "Focus"
    case energy  = "Energy"

    var id: String { rawValue }
    /// Localized lowercase name. `rawValue` is the persisted/English key.
    var displayName: String { L(rawValue.lowercased()) }

    /// SF Symbol shown on the goal option card.
    var icon: String {
        switch self {
        case .clarity: return "sun.max"
        case .peace:   return "leaf"
        case .focus:   return "scope"
        case .energy:  return "bolt.fill"
        }
    }

    /// Badge colour for the goal option card.
    var color: Color {
        switch self {
        case .clarity: return Theme.happy     // warm
        case .peace:   return Theme.confused  // green
        case .focus:   return Theme.cry       // blue
        case .energy:  return Theme.sad       // pink
        }
    }

    var tagline: String {
        switch self {
        case .clarity: return L("clear head, less noise, sharper day.")
        case .peace:   return L("calm before the world gets loud.")
        case .focus:   return L("deep work, fewer distractions.")
        case .energy:  return L("wake up excited to show up.")
        }
    }

    /// Daily journal prompts, gentle lowercase voice. Rotates by day-of-year.
    var prompts: [String] {
        switch self {
        case .clarity:
            return [
                L("what has you curious right now?"),
                L("what thought keeps coming back that deserves attention?"),
                L("what would make today feel clear by the end of it?"),
                L("what are you avoiding that you already know the answer to?"),
                L("what's cluttering your mind this morning?"),
                L("what decision have you been putting off?"),
                L("what's the most honest thing you could write right now?"),
                L("what do you need to say out loud, even just to yourself?"),
            ]
        case .peace:
            return [
                L("what does a peaceful day look like for you today?"),
                L("what can you let go of this morning?"),
                L("what's one thing you don't need to carry today?"),
                L("what would make you feel at ease by tonight?"),
                L("what's a small comfort you can give yourself today?"),
                L("what noise can you turn down in your life right now?"),
                L("what's outside your control that you can set down?"),
                L("where do you feel tension, and what might release it?"),
            ]
        case .focus:
            return [
                L("what's the one thing that would make today feel meaningful?"),
                L("if you could only do one thing today, what would it be?"),
                L("what's the most important thing on your mind right now?"),
                L("what would you regret not doing today?"),
                L("what does a good day look like by tonight?"),
                L("what can you say no to today?"),
                L("what would focused-you do in the next hour?"),
                L("what's one small step toward something you care about?"),
            ]
        case .energy:
            return [
                L("what are you genuinely looking forward to today?"),
                L("what gives you energy when you think about it?"),
                L("what would make you feel proud by tonight?"),
                L("what's a recent win you haven't celebrated yet?"),
                L("what's one thing you're doing today just for you?"),
                L("what would make today feel alive?"),
                L("who or what is motivating you right now?"),
                L("what would your most energized self do first?"),
            ]
        }
    }

    func dailyPrompt(for date: Date = Date()) -> String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        let pool = prompts
        return pool[day % pool.count]
    }
}
