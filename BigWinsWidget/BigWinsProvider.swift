import WidgetKit

/// `nil` affirmation means no quote: either onboarding isn't finished (`needsSetup`) or the
/// widget is locked — it's a Premium feature, so free installs see an upgrade nudge in its place.
struct BigWinsEntry: TimelineEntry {
    let date: Date
    let affirmation: String?
    /// A fresh install, or after "Delete all data": invite the user in rather than show a quote
    /// from topics they haven't picked, or a Premium lock before they've even opened the app.
    var needsSetup = false
    let themeID: String
    let backgroundHex: String?
    let textHex: String
    let fontName: String
}

/// Reads the app-wide topic selection and produces the same daily line as Home and reminders.
/// The line is a pure function of the date and shared selection, so a week of midnights is laid
/// out in one timeline; the app reloads all timelines whenever selection or Premium changes.
struct BigWinsProvider: TimelineProvider {
    private static let daysAhead = 7

    func placeholder(in context: Context) -> BigWinsEntry {
        makeEntry(date: .now, affirmation: Affirmations.library.first?.lines.first ?? "")
    }

    func getSnapshot(in context: Context, completion: @escaping (BigWinsEntry) -> Void) {
        // The widget gallery shows a real line even before Premium — the lock is for the
        // widget on the Home/Lock Screen, not for seeing what it would look like.
        completion(context.isPreview ? placeholder(in: context) : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BigWinsEntry>) -> Void) {
        guard SharedState.onboardingComplete else {
            // Finishing onboarding reloads every timeline.
            completion(Timeline(entries: [setupEntry()], policy: .never))
            return
        }
        guard SharedState.premiumActive else {
            // Nothing to roll over; the Premium ratchet reloads every timeline when it flips.
            completion(Timeline(entries: [makeEntry(date: .now, affirmation: nil)], policy: .never))
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
                .map { makeEntry(date: $0, affirmation: widgetLine(on: $0)) }
        }
    }

    private func currentEntry() -> BigWinsEntry {
        guard SharedState.onboardingComplete else { return setupEntry() }
        guard SharedState.premiumActive else {
            return makeEntry(date: .now, affirmation: nil)
        }
        return makeEntry(date: .now, affirmation: widgetLine(on: .now))
    }

    private func setupEntry() -> BigWinsEntry {
        makeEntry(date: .now, affirmation: nil, needsSetup: true)
    }

    private func makeEntry(date: Date, affirmation: String?, needsSetup: Bool = false) -> BigWinsEntry {
        BigWinsEntry(date: date,
                     affirmation: affirmation,
                     needsSetup: needsSetup,
                     themeID: SharedState.affirmationWidgetTheme,
                     backgroundHex: SharedState.affirmationWidgetBackgroundColor,
                     textHex: SharedState.affirmationWidgetTextColor,
                     fontName: SharedState.affirmationWidgetFont)
    }

    private func widgetLine(on date: Date) -> String {
        Affirmations.dailyLine(on: date, premium: SharedState.premiumActive)
    }
}
