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
    private(set) var chosen: [String]
    private(set) var savedCustom: [String]
    private(set) var deletedBuiltIns: [String]
    private let storage: AffirmationCollectionStorage

    init() {
        let storage = AffirmationCollectionStorage(
            defaults: SharedState.defaults,
            selectionKey: SharedState.Key.affirmationList,
            customKey: SharedState.Key.customAffirmations,
            library: Affirmations.library.flatMap(\.lines), fallback: Affirmations.defaults,
            deletedKey: SharedState.Key.deletedAffirmations)
        self.storage = storage
        chosen = storage.selection
        savedCustom = storage.custom
        deletedBuiltIns = storage.deleted
    }

    var availableLibrary: [Affirmations.Focus] {
        Affirmations.library.compactMap { focus in
            let lines = focus.lines.filter { !deletedBuiltIns.contains($0) }
            return lines.isEmpty ? nil : .init(title: focus.title, lines: lines)
        }
    }

    var initialSelection: [String] { chosen.isEmpty ? Affirmations.availableDefaults : chosen }

    func set(_ list: [String]) {
        guard list != chosen else { return }
        storage.setSelection(list)
        chosen = storage.selection
        savedCustom = storage.custom
        refreshDelivery()
    }

    @discardableResult
    func saveCustom(_ line: String) -> Bool {
        let added = storage.saveCustom(line)
        savedCustom = storage.custom
        return added
    }

    func delete(_ line: String) {
        storage.delete(line)
        chosen = storage.selection
        savedCustom = storage.custom
        deletedBuiltIns = storage.deleted
        refreshDelivery()
    }

    func clear() {
        storage.clear()
        chosen = []
        savedCustom = []
        deletedBuiltIns = []
        WidgetCenter.shared.reloadAllTimelines()
        AffirmationNudge.cancel()
    }

    private func refreshDelivery() {
        WidgetCenter.shared.reloadAllTimelines()
        AffirmationNudge.schedule()
    }

    /// Today's line from these picks — the same one the widget and today's notification carry.
    func today(premium: Bool) -> String {
        let deleted = Set(deletedBuiltIns)
        return Affirmations.line(on: Date(), from: chosen.filter { !deleted.contains($0) }, premium: premium)
    }
}
