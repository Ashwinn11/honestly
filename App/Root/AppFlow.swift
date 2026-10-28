import SwiftUI
import Observation

enum AppTab: Hashable { case home, library, profile }

@MainActor
@Observable
final class AppFlow {
    var selectedTab: AppTab = .home
    var ritualPresented = false
    var paywallPresented = false
    var widgetAffirmationsPresented = false
    var widgetAffirmationLine: String?

    func startRitual() {
        Haptics.tap()
        ritualPresented = true
    }

    func showPaywall() {
        paywallPresented = true
    }

    func go(to tab: AppTab) {
        Haptics.select()
        selectedTab = tab
    }
}
