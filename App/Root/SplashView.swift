import SwiftUI

/// Cold-launch splash: the mark reveals on paper, holds a beat, then fades to the app.
/// The static launch screen (Info.plist → LaunchBackground) is the same paper color, so there's
/// no flash before this — it just looks like the mark deliberately animating in.
struct SplashView: View {
    var onDone: () -> Void
    @State private var appear = false
    @State private var gone = false

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            Image("LaunchLogo")
                .resizable().scaledToFit()
                .frame(width: DesignScale.s(128), height: DesignScale.s(128))
                .clipShape(RoundedRectangle(cornerRadius: DesignScale.s(29), style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DesignScale.s(29), style: .continuous).stroke(Palette.ink.opacity(0.06), lineWidth: 1))
                .shadow(color: .black.opacity(0.14), radius: DesignScale.s(22), y: DesignScale.s(12))
                .scaleEffect(appear ? 1 : 0.82)
                .opacity(appear ? 1 : 0)
        }
        .opacity(gone ? 0 : 1)
        .onAppear {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.72)) { appear = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeOut(duration: 0.4)) { gone = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onDone() }
            }
        }
    }
}
