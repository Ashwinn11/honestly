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
