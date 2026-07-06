import WidgetKit

/// `nil` affirmation means nothing has been written yet today — the empty state.
struct BigWinsEntry: TimelineEntry {
    let date: Date
    let affirmation: String?
}

/// Reads `SharedState.todayAffirmations` (written by `JournalStore.saveRitual`) rather than
/// SwiftData directly — no live cross-process store needed, and `WidgetCenter.reloadAllTimelines()`
/// (called from the same save) makes the widget reflect a new entry immediately rather than
/// waiting on this timeline's own day-boundary refresh.
struct BigWinsProvider: TimelineProvider {
    func placeholder(in context: Context) -> BigWinsEntry {
        BigWinsEntry(date: .now, affirmation: "I am capable of hard things.")
    }

    func getSnapshot(in context: Context, completion: @escaping (BigWinsEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BigWinsEntry>) -> Void) {
        completion(Timeline(entries: buildEntries(), policy: .after(nextMidnight())))
    }

    /// One entry per affirmation written today, spaced 2 hours apart starting from when they were
    /// saved — the same cadence `AffirmationNudge` uses for its echo notifications, so the widget
    /// and that day's notifications stay in step with each other.
    private func buildEntries() -> [BigWinsEntry] {
        guard SharedState.ritualCompleted() else { return [BigWinsEntry(date: .now, affirmation: nil)] }
        let lines = SharedState.todayAffirmations
        guard !lines.isEmpty else { return [BigWinsEntry(date: .now, affirmation: nil)] }

        let start = SharedState.todayAffirmationsSetAt ?? .now
        return lines.enumerated().map { i, line in
            let date = i == 0 ? start : start.addingTimeInterval(Double(i) * 2 * 3600)
            return BigWinsEntry(date: date, affirmation: line)
        }
    }

    private func currentEntry() -> BigWinsEntry {
        let entries = buildEntries()
        let now = Date()
        return entries.last(where: { $0.date <= now }) ?? entries.first ?? BigWinsEntry(date: now, affirmation: nil)
    }

    private func nextMidnight() -> Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return cal.startOfDay(for: tomorrow)
    }
}
