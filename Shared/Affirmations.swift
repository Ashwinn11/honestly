import SwiftUI

/// The affirmation rotation: a built-in library the user picks from (free: up to `freeLimit`;
/// Premium: unlimited, plus lines of their own), shown one per day — the same line on Home, the
/// widget and the daily notification, cycling back to the first once the list runs out.
///
/// Library lines are stored as their English text, which is also their String Catalog key, so a
/// stored pick re-translates whenever the in-app language changes. Anything the user typed
/// themselves is stored and shown exactly as written — never looked up, never translated.
enum Affirmations {
    struct Focus: Identifiable {
        let title: String
        let lines: [String]
        var id: String { title }
    }

    static let freeLimit = 5

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

    /// What rotates until the user has picked their own — installs from before the picker existed,
    /// or right after "Delete all data". One line from each of the first five focus areas.
    static let defaults: [String] = library.prefix(freeLimit).map { $0.lines[0] }

    static var availableDefaults: [String] {
        let deleted = Set(SharedState.defaults.stringArray(forKey: SharedState.Key.deletedAffirmations) ?? [])
        let preferred = defaults.filter { !deleted.contains($0) }
        return preferred.isEmpty ? Array(library.flatMap(\.lines).filter { !deleted.contains($0) }.prefix(freeLimit)) : preferred
    }

    // MARK: Storage — the app group, so the widget and notification scheduler read the same list

    static var chosen: [String] {
        get { SharedState.defaults.stringArray(forKey: SharedState.Key.affirmationList) ?? [] }
        set { SharedState.defaults.set(newValue, forKey: SharedState.Key.affirmationList) }
    }

    // MARK: Rotation

    /// What actually rotates: the picks (or the defaults), capped at `freeLimit` without Premium.
    static func rotation(from picks: [String], premium: Bool) -> [String] {
        let deleted = Set(SharedState.defaults.stringArray(forKey: SharedState.Key.deletedAffirmations) ?? [])
        let available = picks.filter { !deleted.contains($0) }
        let list = available.isEmpty ? availableDefaults : available
        return premium ? list : Array(list.prefix(freeLimit))
    }

    /// One line per calendar day, walking `rotation` in order. Derived purely from the date, so
    /// the app, the widget and the notification scheduler always land on the same line without
    /// sharing any state beyond the list itself.
    static func line(on date: Date, from picks: [String], premium: Bool) -> String {
        let list = rotation(from: picks, premium: premium)
        guard !list.isEmpty else { return "" }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return list[day % list.count]
    }

    /// The same, reading the stored list and the Premium mirror — for the extensions, which have
    /// neither `AffirmationList` nor `PremiumManager`.
    static func line(on date: Date = Date()) -> String {
        line(on: date, from: chosen, premium: SharedState.premiumActive)
    }

    // MARK: Display

    /// Library lines go through the String Catalog; the user's own words are shown verbatim.
    static func text(_ line: String) -> Text {
        if line.isEmpty { return Text(loc: "Choose your affirmations") }
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
