import SwiftUI
import StoreKit

enum ReviewPrompt {
    private static let milestones: Set<Int> = [1, 7, 30]

    @MainActor
    static func maybeAsk(streak: Int, _ request: RequestReviewAction) {
        guard milestones.contains(streak) else { return }
        let key = "review.asked.\(streak)"
        guard !SharedState.defaults.bool(forKey: key) else { return }
        SharedState.defaults.set(true, forKey: key)
        request()
    }

    static var writeReviewURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(AppConfig.appStoreID)?action=write-review")
    }
}
