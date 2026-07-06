import SwiftUI

struct PaperBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Rectangle()
            .fill(Palette.paper)
            .colorEffect(ShaderLibrary.grain(.float(reduceMotion ? 0 : 0.045)))
            .ignoresSafeArea()
    }
}
