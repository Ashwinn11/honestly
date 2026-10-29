import SwiftUI
import StoreKit

enum ReviewPrompt {
    /// Pages written in all — not a streak, which most people never hold for a week — after which
    /// Honestly asks: once someone has come back a few times, then again as the habit settles.
    /// Three asks fit Apple's yearly budget.
    private static let pageMilestones = [3, 10, 30]
    private static let datesKey = "review.requestDates"           // rolling 1-year window of prompts

    /// Timestamps of in-app review prompts in the trailing 365 days (Apple allows ~3/year).
    private static func recentRequests() -> [Double] {
        let now = Date().timeIntervalSince1970
        return (SharedState.defaults.array(forKey: datesKey) as? [Double] ?? [])
            .filter { now - $0 < 365 * 24 * 3600 }
    }
    private static func recordRequest() {
        var d = recentRequests(); d.append(Date().timeIntervalSince1970)
        SharedState.defaults.set(d, forKey: datesKey)
    }

    private static func askedKey(_ milestone: Int) -> String { "review.asked.pages.\(milestone)" }

    /// After a page is closed: asks when the page count has reached a milestone not yet asked
    /// about — but never on a hard day. A page written sad, awful or in tears isn't the moment to
    /// ask for stars, so the ask waits for the next good page instead of being spent.
    @MainActor
    static func maybeAsk(pages: Int, mood: Int, _ request: RequestReviewAction) {
        let due = pageMilestones.filter { $0 <= pages && !SharedState.defaults.bool(forKey: askedKey($0)) }
        guard !due.isEmpty else { return }
        guard mood == Mood.happy.rawValue || mood == Mood.confused.rawValue else { return }
        guard recentRequests().count < 3 else { return }
        // Someone arriving with many pages already is asked once, not once per milestone passed.
        for milestone in due { SharedState.defaults.set(true, forKey: askedKey(milestone)) }
        request(); recordRequest()
    }

    /// The "Rate Honestly" button: show the in-app prompt while within the ~3/year window,
    /// otherwise send the user to the App Store's write-review page.
    @MainActor
    static func rate(_ request: RequestReviewAction, open: (URL) -> Void) {
        if recentRequests().count < 3 {
            request(); recordRequest()
        } else if let url = writeReviewURL {
            open(url)
        }
    }

    static var writeReviewURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(AppConfig.appStoreID)?action=write-review")
    }
}
