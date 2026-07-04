import SwiftUI
import Observation

enum AppTab: Hashable { case home, calendar, history, profile }

@MainActor
@Observable
final class AppFlow {
    var selectedTab: AppTab = .home
    var ritualPresented = false
    var paywallPresented = false

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
