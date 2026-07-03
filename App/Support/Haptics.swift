import UIKit

/// Thin wrapper over UIKit feedback generators. Honestly leans on gentle, tactile feedback —
/// soft taps on selection, a success buzz when the morning page is done.
enum Haptics {
    static func tap()     { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func light()   { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func rigid()   { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func select()  { UISelectionFeedbackGenerator().selectionChanged() }
}
