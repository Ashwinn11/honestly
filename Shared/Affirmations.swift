import SwiftUI

/// Built-in and user-written affirmation content, selected by topic for each delivery surface.
enum Affirmations {
    struct Focus: Identifiable {
        let title: String
        let lines: [String]
        var id: String { title }
    }

    static let library: [Focus] = [
        .init(title: "Self-worth", lines: [
            "I am enough, exactly as I am today.",
            "I don't have to earn my rest.",
            "My worth isn't measured by what I get done.",
            "I'm allowed to take up space.",
            "I deserve the kindness I give to others.",
        ]),
        .init(title: "Calm", lines: [
            "I can take this one breath at a time.",
            "I don't have to solve everything today.",
            "Today, I choose calm over chaos.",
            "I can slow down and still get there.",
            "This feeling is real, and it will pass.",
        ]),
        .init(title: "Confidence", lines: [
            "I am capable of hard things.",
            "I trust myself to figure it out.",
            "I've handled hard days before. I can handle this one.",
            "My voice matters.",
            "I'm becoming someone I'm proud of.",
        ]),
        .init(title: "Hard days", lines: [
            "It's okay to have a slow morning.",
            "I'm doing my best, and that counts.",
            "I can be gentle with myself today.",
            "Small steps still move me forward.",
            "Not every day has to be a good day.",
        ]),
        .init(title: "Intention", lines: [
            "Today, I'll do one thing at a time.",
            "Today, I choose what gets my attention.",
            "My morning is mine. The phone can wait.",
            "Today, I'll keep one promise to myself.",
            "I'll show up for myself before anyone else.",
        ]),
        .init(title: "Gratitude", lines: [
            "There's more good in my life than I notice.",
            "I'm grateful for this quiet morning.",
            "Something good can happen today.",
            "I'm thankful for the people who show up for me.",
            "Today, I'll notice one small good thing.",
        ]),
    ]

    private static let libraryLines = Set(library.flatMap(\.lines))
    static func isLibrary(_ line: String) -> Bool { libraryLines.contains(line) }

    // MARK: Topic based delivery

    /// An empty topic selection means all available affirmation topics.
    static func topicRotation(focusTitles: [String], premium: Bool) -> [String] {
        let deleted = Set(SharedState.defaults.stringArray(forKey: SharedState.Key.deletedAffirmations) ?? [])
        let includeOwn = premium && (focusTitles.isEmpty || focusTitles.contains("Your own"))
        let chosenFocuses = focusTitles.isEmpty ? library.map(\.title) : focusTitles.filter { $0 != "Your own" }
        let selected = library.filter { chosenFocuses.contains($0.title) }.flatMap(\.lines).filter { !deleted.contains($0) }
        let custom = includeOwn ? SharedState.defaults.stringArray(forKey: SharedState.Key.customAffirmations) ?? [] : []
        let available = selected + custom
        return available
    }

    static func feedRotation(focusTitles: [String], premium: Bool) -> [String] {
        topicRotation(focusTitles: focusTitles, premium: premium)
    }

    static func deliveryLine(on date: Date, occurrence: Int = 0, focusTitles: [String], premium: Bool) -> String {
        let list = topicRotation(focusTitles: focusTitles, premium: premium)
        guard !list.isEmpty else { return "" }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return list[(day + occurrence) % list.count]
    }

    static func feedLine(on date: Date, focusTitles: [String], premium: Bool) -> String {
        let list = feedRotation(focusTitles: focusTitles, premium: premium)
        guard !list.isEmpty else { return "" }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return list[day % list.count]
    }

    // MARK: Display

    /// Library lines go through the String Catalog; the user's own words are shown verbatim.
    static func text(_ line: String) -> Text {
        if line.isEmpty { return Text(loc: "No affirmations available") }
        return isLibrary(line) ? Text(loc: line) : Text(verbatim: line)
    }

    /// `text(_:)` for non-SwiftUI callers (notifications), in the in-app language rather than the
    /// device's — the widget forces that same language, so the two never disagree.
    static func display(_ line: String) -> String {
        isLibrary(line) ? localized(line) : line
    }

    /// A String Catalog lookup in the in-app language. `String(localized:)` would follow the
    /// device language instead, which the in-app picker can override.
    static func localized(_ key: String) -> String {
        L10n.localized(key)
    }
}
