import SwiftUI

/// Which month book to open, and the page to open it at. Pushed on the tab's NavigationStack;
/// `MainTabView` turns it into a month-scoped `EntryDetailView`.
struct MonthBookRoute: Hashable {
    /// Opens a book at its grid of all pages; also the key of the title page in front of its first
    /// page, where curling back to the grid lands.
    static let gridKey = "book-grid"

    let year: Int
    let month: Int
    let startKey: String
    init(year: Int, month: Int, startKey: String) {
        self.year = year
        self.month = month
        self.startKey = startKey
    }

    /// The book an entry lives in, opened at that entry.
    init(entry: JournalEntry) {
        let c = Calendar.current.dateComponents([.year, .month], from: entry.date)
        self.init(year: c.year ?? 0, month: c.month ?? 0, startKey: entry.dayKey)
    }

    var firstOfMonth: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }
}

/// One month of pages, shown as a book on the Library shelf.
struct MonthBook: Identifiable {
    let year: Int
    let month: Int
    let entries: [JournalEntry]          // oldest first — the order the pages turn
    let isCurrent: Bool

    var id: String { "\(year)-\(month)" }

    var firstOfMonth: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    /// Opens on the grid of all pages; nil while the month has no pages yet.
    var route: MonthBookRoute? {
        entries.isEmpty ? nil : MonthBookRoute(year: year, month: month, startKey: MonthBookRoute.gridKey)
    }
}
