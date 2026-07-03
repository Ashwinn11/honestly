import SwiftUI
import Observation

/// The four main tabs, referenced by both the tab shell and any screen that needs to switch tabs.
enum AppTab: Hashable { case home, calendar, history, profile }

/// App-wide navigation state: the selected tab plus the modally-presented flows (ritual + paywall),
/// so any screen can drive navigation without threading bindings through the view tree.
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
