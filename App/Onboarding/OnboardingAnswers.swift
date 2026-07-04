import Foundation
import Observation

/// The user's answers as they move through the onboarding funnel. Held for the duration of
/// onboarding, then persisted to `SharedState` on finish so the paywall and the app can read
/// the stated goal, weekly commitment, and scroll time. Every field drives something real —
/// nothing here is collected for its own sake.
@MainActor
@Observable
final class OnboardingAnswers {
    /// Up to two goals; the first chosen is treated as primary for the paywall.
    var goals: [OnbGoal] = []
    /// Self-reported minutes scrolling first thing (feeds the reclaimed-time math). 0 = unset.
    var scrollMinutes: Int = 0
    /// Brand chips the user tapped as "the apps that steal my mornings" — used to NAME apps in the
    /// plan reveal. The real block list is whatever they choose in the Screen Time picker.
    var pickedBrands: [Brand] = []
    /// Mornings-per-week commitment.
    var weeklyGoal: Int = 5

    // MARK: Derived

    var primaryGoal: OnbGoal { goals.first ?? .calmStart }

    /// Hours/month currently lost to the morning scroll (the pain-reveal number).
    var painHours: Int { AppContent.painHours(scrollMin: scrollMinutes) }

    /// Hours/month taken back once the ritual replaces the scroll (the plan/paywall payoff).
    var reclaimedHours: Int {
        AppContent.reclaimedHours(scrollMin: scrollMinutes, morningsPerWeek: weeklyGoal)
    }

    /// The apps named in the plan reveal, e.g. "Instagram, TikTok & X". Falls back gracefully.
    var appsPhrase: String {
        let names = pickedBrands.prefix(3).map(\.displayName)
        switch names.count {
        case 0: return "your loudest apps"
        case 1: return names[0]
        case 2: return "\(names[0]) & \(names[1])"
        default: return "\(names[0]), \(names[1]) & \(names[2])"
        }
    }

    // MARK: Selection helpers

    func toggleGoal(_ g: OnbGoal) {
        if let i = goals.firstIndex(of: g) {
            goals.remove(at: i)
        } else if goals.count < 2 {
            goals.append(g)
        }
    }
    func isGoalSelected(_ g: OnbGoal) -> Bool { goals.contains(g) }

    func toggleBrand(_ b: Brand) {
        if let i = pickedBrands.firstIndex(of: b) { pickedBrands.remove(at: i) }
        else { pickedBrands.append(b) }
    }
    func isBrandPicked(_ b: Brand) -> Bool { pickedBrands.contains(b) }

    // MARK: Persistence

    /// Write the answers out so the rest of the app can personalize around them.
    func persist() {
        SharedState.onboardingGoal = primaryGoal.rawValue
        SharedState.weeklyGoal     = weeklyGoal
        SharedState.scrollMinutes  = scrollMinutes
    }
}

extension Brand {
    /// Human name for use in sentences (the plan reveal).
    var displayName: String {
        switch self {
        case .instagram: return "Instagram"
        case .tiktok:    return "TikTok"
        case .youtube:   return "YouTube"
        case .snapchat:  return "Snapchat"
        case .x:         return "X"
        case .whatsapp:  return "WhatsApp"
        }
    }
}
