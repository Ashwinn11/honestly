import WidgetKit

/// `nil` affirmation means locked — the widget is a Premium feature, so free installs see an
/// upgrade nudge in its place.
struct BigWinsEntry: TimelineEntry {
    let date: Date
    let affirmation: String?
}

/// Reads the rotation from the app group (`Affirmations.chosen` + the `premiumActive` mirror)
/// rather than anything in the app process. The line is a pure function of the day, so a week of
/// midnights is laid out in one timeline; the app calls `WidgetCenter.reloadAllTimelines()`
/// whenever the list or Premium changes, so edits show up immediately rather than next week.
struct BigWinsProvider: TimelineProvider {
    private static let daysAhead = 7

    func placeholder(in context: Context) -> BigWinsEntry {
        BigWinsEntry(date: .now, affirmation: Affirmations.defaults[0])
    }

    func getSnapshot(in context: Context, completion: @escaping (BigWinsEntry) -> Void) {
        // The widget gallery shows a real line even before Premium — the lock is for the
        // widget on the Home/Lock Screen, not for seeing what it would look like.
        completion(context.isPreview ? placeholder(in: context) : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BigWinsEntry>) -> Void) {
        guard SharedState.premiumActive else {
            // Nothing to roll over; the Premium ratchet reloads every timeline when it flips.
            completion(Timeline(entries: [BigWinsEntry(date: .now, affirmation: nil)], policy: .never))
            return
        }
        completion(Timeline(entries: dailyEntries(), policy: .atEnd))
    }

    /// One entry per midnight, starting today.
    private func dailyEntries() -> [BigWinsEntry] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<Self.daysAhead).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: today)
                .map { BigWinsEntry(date: $0, affirmation: Affirmations.line(on: $0)) }
        }
    }

    private func currentEntry() -> BigWinsEntry {
        guard SharedState.premiumActive else { return BigWinsEntry(date: .now, affirmation: nil) }
        return BigWinsEntry(date: .now, affirmation: Affirmations.line(on: .now))
    }
}
