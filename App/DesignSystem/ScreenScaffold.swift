import SwiftUI

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
                    .padding(.horizontal, DesignScale.s(hPadding))
                    .padding(.top, DesignScale.s(topPadding))
                    .padding(.bottom, DesignScale.s(bottomPadding))
                    .capWidth(Metrics.maxContentWidth)       // centered column on iPad; bg stays full-bleed
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(.container, edges: .top)
        }
    }
}
