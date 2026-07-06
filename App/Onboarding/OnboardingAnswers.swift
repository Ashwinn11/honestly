import Foundation
import Observation

@MainActor
@Observable
final class OnboardingAnswers {
    var goals: [OnbGoal] = []
    var scrollMinutes: Int = 0
    var pickedBrands: [Brand] = []
    var weeklyGoal: Int = 5

    // MARK: The "try it now" demo (one real rep of the ritual, done during onboarding)
    var demoMood: Int? = nil
    var demoLine: String = ""
    var demoAffirmation: String = ""

    var demoReady: Bool {
        demoMood != nil && !demoLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Derived

    var primaryGoal: OnbGoal { goals.first ?? .calmStart }

    var painHours: Int { AppContent.painHours(scrollMin: scrollMinutes) }

    var reclaimedHours: Int {
        AppContent.reclaimedHours(scrollMin: scrollMinutes, morningsPerWeek: weeklyGoal)
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

    func persist() {
        SharedState.onboardingGoal = primaryGoal.rawValue
        SharedState.weeklyGoal     = weeklyGoal
        SharedState.scrollMinutes  = scrollMinutes
        if let demoMood { SharedState.demoMood = demoMood }
        SharedState.demoLine        = demoLine
        SharedState.demoAffirmation = demoAffirmation
    }
}

extension Brand {
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
