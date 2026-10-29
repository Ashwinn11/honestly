import Foundation

enum HDate {
    /// The app's selected language drives month/weekday names, and re-creating the formatter each
    /// call means a live language switch updates dates too.
    static var appLocale: Locale { Locale(identifier: SharedState.language) }

    private static func fmt(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = appLocale
        f.setLocalizedDateFormatFromTemplate(pattern)
        return f
    }

    static func homeHeader(_ d: Date) -> String { fmt("EEE '·' MMM d").string(from: d) }   // Sat · Jul 4
    static func monthDay(_ d: Date) -> String { fmt("MMM d").string(from: d) }               // Jul 4
    static func dayMonthYear(_ d: Date) -> String { fmt("d MMM, yyyy").string(from: d) }     // 17 Jul, 2026
    static func monthTitle(_ d: Date) -> String { fmt("MMMM yyyy").string(from: d) }          // July 2026
    static func monthName(_ d: Date) -> String {                                              // July
        let f = DateFormatter()
        f.locale = appLocale
        f.dateFormat = "LLLL"          // stand-alone month name, as it reads alone on a book cover
        return f.string(from: d)
    }
    static func monthShort(_ d: Date) -> String { fmt("MMM").string(from: d) }                // Jul
    static func dayNumber(_ d: Date) -> String { fmt("dd").string(from: d) }                 // 04
    static func year(_ d: Date) -> String { fmt("yyyy").string(from: d) }                    // 2026

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
