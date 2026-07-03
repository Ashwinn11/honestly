import Foundation

/// All the writing content, transcribed verbatim from the prototype (`Honestly.dc.html`):
/// journal prompts, gratitude placeholders, and the ten onboarding slides.
enum AppContent {

    // MARK: Ritual prompts (shuffle pool)
    static let prompts: [String] = [
        "What's sitting on your chest this morning?",
        "If today went well, what happened?",
        "What are you avoiding — and why?",
        "What do you need to hear right now?",
        "Who or what is taking up space in your head?",
        "What would 'enough' look like today?",
        "What's one honest thing you haven't said out loud?",
        "How do you actually feel, before the coffee kicks in?",
    ]

    /// The prompt the ritual opens on (prototype starts at index 2).
    static let defaultPromptIndex = 2

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

    // MARK: Onboarding — the ten slides
    static let onboarding: [OnbSlide] = [
        .init(kind: .brand,  title: "Honestly",
              body: "The quiet part of the morning — before the world logs on."),
        .init(kind: .noise,  title: "The first thing you touch each morning runs the whole day.",
              body: "Reach for the phone and a hundred other voices get there before yours does."),
        .init(kind: .page,   title: "So we give your mind a page before the world gets one.",
              body: "Unfiltered. Unedited. Nobody watching. Just you, first."),
        .init(kind: .moods,  title: "It starts with how you actually feel.",
              body: "Tap a face. There are no wrong answers at 6am."),
        .init(kind: .write,  title: "Then you empty your head onto the page.",
              body: "Worries, plans, nonsense — let it spill. It stays yours and only yours."),
        .init(kind: .grat,   title: "And you finish on five small good things.",
              body: "Gratitude is a muscle. You'll flex it every single morning."),
        .init(kind: .quiet,  title: "We keep the noise asleep while you write.",
              body: "Your loudest apps stay locked until the page is done — powered by Screen Time. The quiet is the whole point."),
        .init(kind: .streak, title: "Show up, and watch it grow.",
              body: "A little each morning. Your streak is proof you kept a promise to yourself."),
        .init(kind: .notif,  title: "One gentle nudge each morning?",
              body: "No badges, no bait — just a nudge to meet yourself before the day does."),
        .init(kind: .ready,  title: "Good morning, you.",
              body: "Tomorrow, we'll be right here. Before everyone else."),
    ]
}

struct OnbSlide: Identifiable {
    let id = UUID()
    let kind: OnbKind
    let title: String
    let body: String
    var hasText: Bool { kind != .brand }
}

enum OnbKind { case brand, noise, page, moods, write, grat, quiet, streak, notif, ready }
