import SwiftUI
import Observation

enum AppTab: Hashable { case home, calendar, history, profile }

@MainActor
@Observable
final class AppFlow {
    var selectedTab: AppTab = ScreenshotPreview.screen == "calendar" ? .calendar : ScreenshotPreview.screen == "history" ? .history : .home
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

/// Deterministic sample data for real simulator captures. Unavailable in device and release builds.
enum ScreenshotPreview {
    static var screen: String? {
        #if DEBUG && targetEnvironment(simulator)
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--screenshot"), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
        #else
        return nil
        #endif
    }
    static var enabled: Bool { screen != nil }
    static let journal = "This morning, I left my phone on the table and opened the window instead.\n\nThe air was cool. My coffee was still warm. For once, there was nothing I needed to catch up on.\n\nToday, I want to do one thing at a time. Listen a little longer. Leave room for something good."
}
