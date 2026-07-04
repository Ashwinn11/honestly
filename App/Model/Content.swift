import Foundation

enum AppContent {

    // MARK: Ritual prompts — a distinct pool per mood (index 0…4) so writing never feels repetitive.
    static func prompts(for mood: Int) -> [String] {
        let i = min(max(mood, 0), 4)
        return promptsByMood[i]
    }

    static let promptsByMood: [[String]] = [
        [
            "What's making this morning feel good?",
            "What do I want to carry into the rest of today?",
            "What's one thing I'm genuinely looking forward to?",
            "Who would I love to share this feeling with?",
            "What went right lately that I haven't fully savored?",
            "What does my best version of today look like?",
            "What's a small win I can build on?",
            "What am I grateful for right now, honestly?",
            "How can I protect this good mood today?",
            "What am I quietly proud of lately?",
        ],
        [
            "What am I trying to figure out?",
            "What feels unclear right now — and why?",
            "If I already knew the answer, what would it be?",
            "What decision am I avoiding?",
            "What question is really underneath this one?",
            "What do I actually want, before I talk myself out of it?",
            "What would make today feel a little clearer?",
            "What am I overthinking?",
            "Whose opinion am I letting cloud my own?",
            "What's one small thing I can decide today?",
        ],
        [
            "What's weighing on me this morning?",
            "What do I need to hear right now?",
            "Where do I feel this sadness in my body?",
            "What would I say to a friend who felt like this?",
            "What's one small kindness I can give myself today?",
            "What am I grieving, even quietly?",
            "What would 'gentle' look like for me today?",
            "What do I wish someone understood?",
            "What's still okay, even now?",
            "What can I let myself feel without trying to fix it?",
        ],
        [
            "What's making today feel like too much?",
            "What's the one thing I truly have to do — and what can wait?",
            "What do I need just to get through the next hour?",
            "What am I carrying that isn't mine to carry?",
            "Where can I lower the bar today?",
            "What would help, even 1%?",
            "Who could I ask for help?",
            "What's the kindest thing I could do for myself right now?",
            "What do I want to let go of before the day starts?",
            "If today is just about getting through, what does that look like?",
        ],
        [
            "What do I need to let out this morning?",
            "What's really hurting right now?",
            "What have I been holding in?",
            "What would it feel like to be fully honest here?",
            "Who or what do I miss?",
            "What do I need to forgive myself for?",
            "What's the truest thing I can write right now?",
            "What would actually comfort me today?",
            "What am I not saying out loud?",
            "What do I need to grieve before I can move?",
        ],
    ]

    // MARK: Journal
    static let journalPlaceholder = "Start anywhere. No one reads this but you."
    static let emptyJournalFallback = "Left the page quiet today — and that counts too."

    static func journalHint(wordCount: Int) -> String {
        wordCount == 0 ? "This page is just for you."
            : "\(wordCount) " + (wordCount == 1 ? "word — keep going" : "words — nice")
    }

    // MARK: Gratitude
    static func gratitudePlaceholder(_ index: Int) -> String {
        index == 0 ? "the first thing that comes to mind…" : "one more small thing…"
    }

    // MARK: - Onboarding funnel

    static let onbBrandTagline  = "The quiet part of the morning — before the world logs on."
    static let onbProblemTitle  = "The scroll gets\nthere first."
    static let onbProblemBody   = "A hundred voices, before yours."

    // MARK: Quiet your apps (o6 — illustration + single action, no quiz)
    static let onbQuietTitle    = "Put the noisy\napps to sleep"
    static let onbQuietBody     = "They stay quiet each morning until your page is written."

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

    // MARK: The three-step ritual (taught in one screen, condensing the old moods/write/grat slides)
    static let ritualSteps: [RitualStep] = [
        .init(kind: .moods, title: "Name the mood",  body: "Tap a face. No wrong answers at 6am."),
        .init(kind: .write, title: "Empty your head", body: "A couple of minutes. Worries, plans, nonsense — let it spill."),
        .init(kind: .grat,  title: "Five small goods", body: "Finish on gratitude. It's a muscle you'll build daily."),
    ]

    // MARK: The "building your plan" ticks
    static let buildingTitle = "Designing your morning ritual…"
    static let buildingTicks = ["Quieting your apps", "Choosing your prompts", "Setting your streak goal"]

    // MARK: Notification nudge
    static let notifTitle = "One gentle nudge each morning?"
    static let notifBody  = "No badges, no bait — just a nudge to meet yourself before the day does."

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
    var leadBenefit: String {
        switch self {
        case .clearHead, .calmStart: return "leaf.fill"
        case .offPhone:              return "sunrise.fill"
        case .momentForMe:           return "lock.fill"
        case .feelFeelings:          return "flame.fill"
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

struct RitualStep: Identifiable {
    let kind: OnbKind
    let title: String
    let body: String
    var id: String { title }
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

enum OnbKind { case brand, noise, page, moods, write, grat, quiet, streak, notif, ready }
