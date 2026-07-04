import UIKit

enum Haptics {
    static func tap()     { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func light()   { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func rigid()   { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func select()  { UISelectionFeedbackGenerator().selectionChanged() }
}
