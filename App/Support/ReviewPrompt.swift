import SwiftUI
import StoreKit

enum ReviewPrompt {
    private static let milestones: Set<Int> = [1, 7, 30]
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

    /// Auto-prompt at streak milestones — but only while inside Apple's yearly budget.
    @MainActor
    static func maybeAsk(streak: Int, _ request: RequestReviewAction) {
        guard milestones.contains(streak) else { return }
        let key = "review.asked.\(streak)"
        guard !SharedState.defaults.bool(forKey: key) else { return }
        guard recentRequests().count < 3 else { return }
        SharedState.defaults.set(true, forKey: key)
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
