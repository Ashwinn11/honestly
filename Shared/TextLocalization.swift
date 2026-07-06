import SwiftUI

extension Text {
    /// Localize a runtime `String` through the String Catalog (keys are the English source strings).
    /// Use for values that arrive as `String` (content constants, option labels) rather than literals.
    init(loc key: String) { self.init(LocalizedStringKey(key)) }
}
