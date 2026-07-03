import SwiftUI

/// The standard tab-screen container: the paper canvas, a hidden-indicator scroll view, and the
/// prototype's top offset (content begins ~60pt from the true top, status bar overlapping the
/// empty header space). The native tab bar supplies the bottom safe-area inset automatically.
struct ScreenScaffold<Content: View>: View {
    var topPadding: CGFloat = 60
    var hPadding: CGFloat = 20
    var bottomPadding: CGFloat = 20
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            PaperBackground()
            ScrollView {
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, hPadding)
                    .padding(.top, topPadding)
                    .padding(.bottom, bottomPadding)
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(.container, edges: .top)
        }
    }
}
