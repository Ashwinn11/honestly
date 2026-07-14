import Foundation

enum AppContent {

    // MARK: Journal
    static let journalPlaceholder = "Start anywhere. No one reads this but you."
    static let emptyJournalFallback = "Left the page quiet today — and that counts too."

    // MARK: Affirmations — five short starters so each line becomes its own affirmation.
    private static let affirmationStarters = ["I am…", "I can…", "I choose…", "I deserve…", "Today, I…"]
    static func affirmationPlaceholder(_ index: Int) -> String {
        affirmationStarters[index % affirmationStarters.count]
    }
    /// Sent in the affirmation notification until the user has written one of their own.
    static let defaultAffirmation = "I am capable of hard things."

    // MARK: - Onboarding funnel

    static let onbProblemTitle  = "You reach for\nthe phone first."
    static let onbProblemBody   = "Before you've had one thought of your own, the feed has a hundred."

    // MARK: Quiz — goal (multi-select, up to 2)
    static let goalQuestion = "What do you want your mornings to give you?"
    static let goalHint     = "Pick up to two."

    // MARK: Quiz — morning scroll time (single-select; feeds the reclaimed-time math)
    static let scrollQuestion = "How long do you scroll before you're really up?"
    static let scrollOptions: [ScrollOption] = [
        .init(minutes: 5,  label: "Under 5 minutes",        note: "A quick peek"),
        .init(minutes: 15, label: "About 15 minutes",       note: "One thing leads to another"),
        .init(minutes: 30, label: "Half an hour, easy",     note: "The bed swallows me"),
        .init(minutes: 60, label: "An hour or more — honestly", note: "Gone before I'm up"),
    ]

    // MARK: Quiz — the apps (warm-up chips before the real Screen Time picker)
    static let appsQuestion = "Which apps steal your mornings?"
    static let appsHint     = "Tap the usual suspects. Next you'll pick them for real."

    // MARK: Quiz — weekly commitment
    static let commitQuestion = "How many mornings a week will you show up?"
    static let commitOptions: [CommitOption] = [
        .init(perWeek: 3, label: "3 mornings",   note: "Ease into it"),
        .init(perWeek: 5, label: "5 mornings",   note: "Weekday warrior"),
        .init(perWeek: 7, label: "Every morning", note: "All in — who I'm becoming"),
    ]

    // MARK: The "building your plan" ticks
    static let buildingTitle = "Designing your morning ritual…"
    static let buildingTicks = ["Quieting your apps", "Setting up your ritual", "Setting your streak goal"]

    // MARK: Notification nudge
    static let notifTitle = "Hear your own words back?"
    static let notifBody  = "Once you've written a few, we'll echo one back to you — until then, a gentle one to start."

    // MARK: Reclaimed-time math (honest, derived from the user's own answers)

    static func painHours(scrollMin: Int) -> Int {
        max(1, Int((Double(scrollMin) * 30.0 / 60.0).rounded()))
    }

    static func reclaimedHours(scrollMin: Int, morningsPerWeek: Int) -> Int {
        max(1, Int((Double(scrollMin) * Double(morningsPerWeek) * 4.345 / 60.0).rounded()))
    }

    // MARK: Social proof
    static let socialProof = SocialProof(
        rating: "",          // e.g. "4.8"
        ratingsCount: "",    // e.g. "1,200+ ratings"
        quotes: []           // e.g. [.init(text: "…", author: "…")]
    )
}

// MARK: - Funnel model types

enum OnbGoal: String, CaseIterable, Identifiable {
    case clearHead, calmStart, offPhone, momentForMe, feelFeelings
    var id: String { rawValue }

    var option: String {
        switch self {
        case .clearHead:    return "A clearer head"
        case .calmStart:    return "A calmer start"
        case .offPhone:     return "Off the phone, into my day"
        case .momentForMe:  return "A few honest minutes for myself"
        case .feelFeelings: return "To feel what I'm actually feeling"
        }
    }
    var paywallHero: String {
        switch self {
        case .clearHead:    return "A clearer head, every morning"
        case .calmStart:    return "A calmer start to every day"
        case .offPhone:     return "Take your mornings back"
        case .momentForMe:  return "A few honest minutes, daily"
        case .feelFeelings: return "Meet yourself, honestly"
        }
    }
    var planEmpathy: String {
        switch self {
        case .clearHead:    return "Let's clear the morning fog before the world fills it."
        case .calmStart:    return "Let's trade the anxious scroll for a calmer few minutes."
        case .offPhone:     return "Let's get you off the phone and into your actual day."
        case .momentForMe:  return "Let's carve out a few minutes that are only yours."
        case .feelFeelings: return "Let's make space to feel what you're actually feeling."
        }
    }
}

struct ScrollOption: Identifiable {
    let minutes: Int
    let label: String
    let note: String
    var id: Int { minutes }
}

struct CommitOption: Identifiable {
    let perWeek: Int
    let label: String
    let note: String
    var id: Int { perWeek }
}

struct SocialProof {
    let rating: String        // "" until a real App Store rating is supplied
    let ratingsCount: String  // "" until a real ratings count is supplied
    let quotes: [Quote]       // empty until real review quotes are supplied
    var hasStats: Bool { !rating.isEmpty }

    struct Quote: Identifiable {
        let text: String
        let author: String
        var id: String { author + text }
    }
}

enum OnbKind { case brand, noise }

// MARK: - Journal Prompts

/// A single journal prompt tagged with the moods it suits best.
/// moods: 0 = awful/crying, 1 = sad, 2 = meh/okay, 3 = good, 4 = great
struct JournalPrompt: Identifiable {
    let text: String
    let moods: Set<Int>
    var id: String { text }
}

extension AppContent {

    // MARK: Prompt bank (40 prompts, mood-tagged)

    static let journalPrompts: [JournalPrompt] = [

        // ── Morning grounding — all moods ──────────────────────────────
        .init(text: "What's the first feeling you woke up with today?",                 moods: [0,1,2,3,4]),
        .init(text: "What does your body feel like before the day has an opinion?",     moods: [0,1,2,3,4]),
        .init(text: "Where's your head this morning, honestly?",                        moods: [0,1,2,3,4]),
        .init(text: "What would you write if you knew nobody would ever read this?",    moods: [0,1,2,3,4]),

        // ── Grounding — low / heavy moods ─────────────────────────────
        .init(text: "What are you carrying from yesterday that you'd like to set down?", moods: [0,1,2]),
        .init(text: "What's the quietest thing on your mind right now?",                 moods: [1,2,3]),

        // ── Intention — neutral / positive ─────────────────────────────
        .init(text: "If today had one job, what would it be?",                          moods: [2,3,4]),
        .init(text: "What would make this morning feel like it was yours?",             moods: [2,3,4]),
        .init(text: "What's the one thing that would make today feel like a win?",      moods: [2,3,4]),
        .init(text: "What does a good version of today look like?",                     moods: [2,3,4]),
        .init(text: "What do you want to remember to do today — for yourself, not for anyone else?", moods: [3,4]),

        // ── Mental clarity — mid moods ─────────────────────────────────
        .init(text: "What's been sitting in the back of your mind?",                    moods: [1,2,3]),
        .init(text: "What thought keeps coming back that you haven't said out loud yet?", moods: [0,1,2]),
        .init(text: "What are you pretending not to think about?",                      moods: [1,2,3]),
        .init(text: "What's something you know you need to do, but keep pushing off?",  moods: [2,3]),
        .init(text: "What's quietly weighing on you right now?",                        moods: [0,1,2]),

        // ── Self-compassion — low moods ────────────────────────────────
        .init(text: "What would a good friend say to you about where you are right now?", moods: [0,1,2]),
        .init(text: "What do you need to hear this morning that nobody's said yet?",    moods: [0,1,2]),
        .init(text: "What have you been too hard on yourself about lately?",            moods: [0,1,2]),
        .init(text: "What's one small thing you did yesterday that deserves a quiet nod?", moods: [0,1,2,3]),
        .init(text: "What would you tell a friend who felt exactly the way you do today?", moods: [0,1,2]),

        // ── Growth & letting go ────────────────────────────────────────
        .init(text: "What do you want to leave behind this morning?",                   moods: [0,1,2]),
        .init(text: "What's something you've been meaning to forgive yourself for?",    moods: [0,1,2]),
        .init(text: "What old story about yourself are you ready to stop believing?",   moods: [1,2,3]),
        .init(text: "What's one thing you want to grow toward, even just a little, today?", moods: [2,3,4]),
        .init(text: "What's something recent that surprised you about yourself?",       moods: [2,3,4]),

        // ── Light & forward-looking — positive moods ───────────────────
        .init(text: "What are you quietly looking forward to?",                         moods: [2,3,4]),
        .init(text: "What's one thing that could go really right today?",               moods: [2,3,4]),
        .init(text: "What used to light you up that you've lost touch with lately?",    moods: [1,2,3]),
        .init(text: "What would you do today if you weren't afraid of getting it wrong?", moods: [2,3,4]),
        .init(text: "What's one small pleasure you could give yourself today?",         moods: [1,2,3,4]),

        // ── Energy & resistance ────────────────────────────────────────
        .init(text: "What's draining you that you haven't named yet?",                  moods: [0,1,2]),
        .init(text: "What feels heavy? What feels light?",                              moods: [0,1,2]),
        .init(text: "What are you avoiding, and what does that avoidance cost you?",    moods: [1,2,3]),
        .init(text: "Where do you need to draw a line today?",                          moods: [2,3]),
        .init(text: "What obligation today is real, and which ones did you make up?",   moods: [2,3,4]),

        // ── Deep honest check-ins ──────────────────────────────────────
        .init(text: "What version of yourself showed up yesterday — and is that who you want to be today?", moods: [2,3]),
        .init(text: "What do you wish people understood about you right now?",          moods: [0,1,2]),
        .init(text: "What's a feeling you've been labelling as something else?",        moods: [0,1,2]),
        .init(text: "What does the most honest version of you want to say today?",      moods: [1,2,3]),
    ]

    // MARK: Helpers

    /// Returns prompts that match the given mood (0–4). Falls back to the full bank if mood is nil
    /// or the filtered set would be empty.
    static func prompts(for mood: Int?) -> [JournalPrompt] {
        guard let mood else { return journalPrompts }
        let filtered = journalPrompts.filter { $0.moods.contains(mood) }
        return filtered.isEmpty ? journalPrompts : filtered
    }

    /// Picks a stable index within `pool` based on the day-of-year, so the same prompt appears all
    /// session but rotates daily. Deterministic — no random state needed on first load.
    static func dailyPromptIndex(in pool: [JournalPrompt]) -> Int {
        guard !pool.isEmpty else { return 0 }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return day % pool.count
    }
}
