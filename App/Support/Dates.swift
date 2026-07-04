import Foundation

enum HDate {
    /// The app's selected language drives month/weekday names, and re-creating the formatter each
    /// call means a live language switch updates dates too.
    static var appLocale: Locale { Locale(identifier: SharedState.language) }

    private static func fmt(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = appLocale
        f.dateFormat = pattern
        return f
    }

    static func homeHeader(_ d: Date) -> String { fmt("EEE '·' MMM d").string(from: d) }   // Sat · Jul 4
    static func shortLabel(_ d: Date) -> String { fmt("EEE, MMM d").string(from: d) }        // Sat, Jul 4
    static func monthDay(_ d: Date) -> String { fmt("MMM d").string(from: d) }               // Jul 4
    static func longDate(_ d: Date) -> String { fmt("MMM d, yyyy").string(from: d) }          // Jul 4, 2026
    static func weekdayFull(_ d: Date) -> String { fmt("EEEE").string(from: d) }              // Saturday
    static func monthTitle(_ d: Date) -> String { fmt("MMMM yyyy").string(from: d) }          // July 2026
    static func monthShort(_ d: Date) -> String { fmt("MMM").string(from: d) }                // Jul
    static func weekdayShort(_ d: Date) -> String { fmt("EEE").string(from: d) }              // Sat

    static func isToday(_ d: Date) -> Bool { Calendar.current.isDateInToday(d) }
}
