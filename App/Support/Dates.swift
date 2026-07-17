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
    static func monthDay(_ d: Date) -> String { fmt("MMM d").string(from: d) }               // Jul 4
    static func dayMonthYear(_ d: Date) -> String { fmt("d MMM, yyyy").string(from: d) }     // 17 Jul, 2026
    static func weekdayFull(_ d: Date) -> String { fmt("EEEE").string(from: d) }              // Saturday
    static func monthTitle(_ d: Date) -> String { fmt("MMMM yyyy").string(from: d) }          // July 2026
    static func monthShort(_ d: Date) -> String { fmt("MMM").string(from: d) }                // Jul
    static func weekdayShort(_ d: Date) -> String { fmt("EEE").string(from: d) }              // Sat

    static func isToday(_ d: Date) -> Bool { Calendar.current.isDateInToday(d) }

    /// Localization key for a time-of-day greeting — morning / afternoon / evening.
    static func greetingKey(_ d: Date) -> String {
        switch Calendar.current.component(.hour, from: d) {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
}
