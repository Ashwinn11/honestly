import SwiftUI

enum Goal: String, CaseIterable, Codable, Identifiable {
    case clarity = "Clarity"
    case peace   = "Peace"
    case focus   = "Focus"
    case energy  = "Energy"

    var id: String { rawValue }
    var displayName: String { rawValue.lowercased() }

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
        case .clarity: return "clear head, less noise, sharper day."
        case .peace:   return "calm before the world gets loud."
        case .focus:   return "deep work, fewer distractions."
        case .energy:  return "wake up excited to show up."
        }
    }

    /// Daily journal prompts, gentle lowercase voice. Rotates by day-of-year.
    var prompts: [String] {
        switch self {
        case .clarity:
            return [
                "what has you curious right now?",
                "what thought keeps coming back that deserves attention?",
                "what would make today feel clear by the end of it?",
                "what are you avoiding that you already know the answer to?",
                "what's cluttering your mind this morning?",
                "what decision have you been putting off?",
                "what's the most honest thing you could write right now?",
                "what do you need to say out loud, even just to yourself?",
            ]
        case .peace:
            return [
                "what does a peaceful day look like for you today?",
                "what can you let go of this morning?",
                "what's one thing you don't need to carry today?",
                "what would make you feel at ease by tonight?",
                "what's a small comfort you can give yourself today?",
                "what noise can you turn down in your life right now?",
                "what's outside your control that you can set down?",
                "where do you feel tension, and what might release it?",
            ]
        case .focus:
            return [
                "what's the one thing that would make today feel meaningful?",
                "if you could only do one thing today, what would it be?",
                "what's the most important thing on your mind right now?",
                "what would you regret not doing today?",
                "what does a good day look like by tonight?",
                "what can you say no to today?",
                "what would focused-you do in the next hour?",
                "what's one small step toward something you care about?",
            ]
        case .energy:
            return [
                "what are you genuinely looking forward to today?",
                "what gives you energy when you think about it?",
                "what would make you feel proud by tonight?",
                "what's a recent win you haven't celebrated yet?",
                "what's one thing you're doing today just for you?",
                "what would make today feel alive?",
                "who or what is motivating you right now?",
                "what would your most energized self do first?",
            ]
        }
    }

    func dailyPrompt(for date: Date = Date()) -> String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        let pool = prompts
        return pool[day % pool.count]
    }
}
