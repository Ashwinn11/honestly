import SwiftUI

/// The warm-paper canvas every screen sits on. Flat `#FAF8F5` with a whisper of static grain
/// (Metal) so the fill reads as actual paper rather than a flat hex — meant to be felt, not seen.
struct PaperBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Rectangle()
            .fill(Palette.paper)
            .colorEffect(ShaderLibrary.grain(.float(reduceMotion ? 0 : 0.045)))
            .ignoresSafeArea()
    }
}

extension View {
    /// Places the paper-grain canvas behind the content.
    func paperBackground() -> some View {
        background(PaperBackground())
    }
}
