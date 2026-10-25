import Foundation

enum AppContent {

    // MARK: Journal
    static let emptyJournalFallback = "Left the page quiet today — and that counts too."

    // MARK: - Onboarding funnel

    static let onbProblemTitle  = "Before the world,\na moment for you."

    // MARK: App-locking
    static let lockTitle = "Write first.\nScroll later."

    // MARK: Notification nudge
    static let notifTitle = "Choose whether Honestly\ncan notify you."

    // MARK: Social proof
    static let socialProof = SocialProof(
        rating: "5.0 / 5",
        quotes: [
            .init(text: "It's a really good app—it's attractive and minimalist, with no distractions, which makes it perfect for mornings.",
                  author: "Ianm34223"),
            .init(text: "Great way to start my morning", author: "Jamie1430"),
        ]
    )
}

// MARK: - Funnel model types

struct SocialProof {
    let rating: String        // "" until a real App Store rating is supplied
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

/// A built-in journal prompt. Selection is independent of mood.
struct JournalPrompt: Identifiable {
    let text: String
    var id: String { text }
}

extension AppContent {

    // MARK: Prompt bank (40 prompts)

    static let journalPrompts: [JournalPrompt] = [

        // ── Morning grounding — all moods ──────────────────────────────
        .init(text: "What's the first feeling you woke up with today?"),
        .init(text: "What does your body feel like before the day has an opinion?"),
        .init(text: "Where's your head this morning, honestly?"),
        .init(text: "What would you write if you knew nobody would ever read this?"),

        // ── Grounding — low / heavy moods ─────────────────────────────
        .init(text: "What are you carrying from yesterday that you'd like to set down?"),
        .init(text: "What's the quietest thing on your mind right now?"),

        // ── Intention — neutral / positive ─────────────────────────────
        .init(text: "If today had one job, what would it be?"),
        .init(text: "What would make this morning feel like it was yours?"),
        .init(text: "What's the one thing that would make today feel like a win?"),
        .init(text: "What does a good version of today look like?"),
        .init(text: "What do you want to remember to do today — for yourself, not for anyone else?"),

        // ── Mental clarity — mid moods ─────────────────────────────────
        .init(text: "What's been sitting in the back of your mind?"),
        .init(text: "What thought keeps coming back that you haven't said out loud yet?"),
        .init(text: "What are you pretending not to think about?"),
        .init(text: "What's something you know you need to do, but keep pushing off?"),
        .init(text: "What's quietly weighing on you right now?"),

        // ── Self-compassion — low moods ────────────────────────────────
        .init(text: "What would a good friend say to you about where you are right now?"),
        .init(text: "What do you need to hear this morning that nobody's said yet?"),
        .init(text: "What have you been too hard on yourself about lately?"),
        .init(text: "What's one small thing you did yesterday that deserves a quiet nod?"),
        .init(text: "What would you tell a friend who felt exactly the way you do today?"),

        // ── Growth & letting go ────────────────────────────────────────
        .init(text: "What do you want to leave behind this morning?"),
        .init(text: "What's something you've been meaning to forgive yourself for?"),
        .init(text: "What old story about yourself are you ready to stop believing?"),
        .init(text: "What's one thing you want to grow toward, even just a little, today?"),
        .init(text: "What's something recent that surprised you about yourself?"),

        // ── Light & forward-looking — positive moods ───────────────────
        .init(text: "What are you quietly looking forward to?"),
        .init(text: "What's one thing that could go really right today?"),
        .init(text: "What used to light you up that you've lost touch with lately?"),
        .init(text: "What would you do today if you weren't afraid of getting it wrong?"),
        .init(text: "What's one small pleasure you could give yourself today?"),

        // ── Energy & resistance ────────────────────────────────────────
        .init(text: "What's draining you that you haven't named yet?"),
        .init(text: "What feels heavy? What feels light?"),
        .init(text: "What are you avoiding, and what does that avoidance cost you?"),
        .init(text: "Where do you need to draw a line today?"),
        .init(text: "What obligation today is real, and which ones did you make up?"),

        // ── Deep honest check-ins ──────────────────────────────────────
        .init(text: "What version of yourself showed up yesterday — and is that who you want to be today?"),
        .init(text: "What do you wish people understood about you right now?"),
        .init(text: "What's a feeling you've been labelling as something else?"),
        .init(text: "What does the most honest version of you want to say today?"),
    ]

}
