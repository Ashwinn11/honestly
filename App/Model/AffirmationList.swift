import Foundation
import Observation
import WidgetKit

/// The app-side face of the user's affirmation picks: observable, so Home and Profile redraw the
/// moment the list changes, and the single write path that fans a change out to everything else
/// that shows it — the widget's timeline and the queued daily notifications. The list itself
/// lives in the app group (`Affirmations.chosen`) so the widget can read it too.
@MainActor
@Observable
final class AffirmationList {
    private(set) var chosen: [String] = Affirmations.chosen

    func set(_ list: [String]) {
        guard list != chosen else { return }
        chosen = list
        Affirmations.chosen = list
        WidgetCenter.shared.reloadAllTimelines()
        AffirmationNudge.schedule()
    }

    /// Today's line from these picks — the same one the widget and today's notification carry.
    func today(premium: Bool) -> String {
        Affirmations.line(on: Date(), from: chosen, premium: premium)
    }
}
