import Foundation

/// Shared date formatting so every screen labels days identically (matches the prototype's
/// "Sat · Jul 4", "Jul 4", "July 2026" formats).
enum HDate {
    private static func fmt(_ pattern: String) -> DateFormatter {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = pattern; return f
    }
    private static let header   = fmt("EEE '·' MMM d")     // Sat · Jul 4
    private static let short    = fmt("EEE, MMM d")        // Sat, Jul 4
    private static let monthDay = fmt("MMM d")             // Jul 4
    private static let long     = fmt("MMM d, yyyy")       // Jul 4, 2026
    private static let weekday  = fmt("EEEE")              // Saturday
    private static let month    = fmt("MMMM yyyy")         // July 2026
    private static let monthAbbr = fmt("MMM")              // Jul
    private static let wdShort  = fmt("EEE")               // Sat

    static func homeHeader(_ d: Date) -> String { header.string(from: d) }
    static func shortLabel(_ d: Date) -> String { short.string(from: d) }
    static func monthDay(_ d: Date) -> String { monthDay.string(from: d) }
    static func longDate(_ d: Date) -> String { long.string(from: d) }
    static func weekdayFull(_ d: Date) -> String { weekday.string(from: d) }
    static func monthTitle(_ d: Date) -> String { month.string(from: d) }
    static func monthShort(_ d: Date) -> String { monthAbbr.string(from: d) }
    static func weekdayShort(_ d: Date) -> String { wdShort.string(from: d) }

    static func isToday(_ d: Date) -> Bool { Calendar.current.isDateInToday(d) }

    /// Relative label used in list rows: "Today" for today, otherwise "Sat, Jul 4".
    static func rowDate(_ d: Date) -> String { isToday(d) ? "Today" : shortLabel(d) }
}
