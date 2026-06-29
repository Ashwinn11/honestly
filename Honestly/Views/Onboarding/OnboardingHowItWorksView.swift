import SwiftUI

struct OnboardingHowItWorksView: View {
    let stepIndex: Int
    let onNext: () -> Void
    let onBack: () -> Void

    // (illustration asset, title, subtitle)
    private let steps: [(String, String, String)] = [
        ("art-sunrise", "name the weather", "tap how the inside feels today."),
        ("art-journal", "write a little",    "a gentle prompt, then a gratitude."),
        ("art-window",  "unlock your day",   "apps open, plant grows. go gently."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    OnboardingHeader(eyebrow: "the morning, in three breaths",
                                     title: "how it works",
                                     alignment: .center)

                    VStack(spacing: 22) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { _, s in
                            HStack(spacing: 14) {
                                Image(s.0)
                                    .resizable().scaledToFit()
                                    .frame(width: AppLayout.s(64), height: AppLayout.s(64))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(s.1)
                                        .font(AppFont.bodyBold(19))
                                        .foregroundStyle(Theme.ink)
                                    Text(s.2)
                                        .font(AppFont.accent(16))
                                        .foregroundStyle(Theme.inkFaint)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                            }
                        }
                    }
                    .frame(maxWidth: AppLayout.s(320))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            }

            OnboardingBottomBar(stepIndex: stepIndex, primaryTitle: "got it",
                                onBack: onBack, onPrimary: onNext)
        }
    }
}
