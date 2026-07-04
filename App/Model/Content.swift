import Foundation

/// All the writing content, transcribed verbatim from the prototype (`Honestly.dc.html`):
/// journal prompts, gratitude placeholders, and the ten onboarding slides.
enum AppContent {

    // MARK: Ritual prompts — a distinct pool per mood (index 0…4) so writing never feels repetitive.
    static func prompts(for mood: Int) -> [String] {
        let i = min(max(mood, 0), 4)
        return promptsByMood[i]
    }

    static let promptsByMood: [[String]] = [
        // 0 · Happy
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
        // 1 · Confused
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
        // 2 · Sad
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
        // 3 · Awful
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
        // 4 · Cry
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
