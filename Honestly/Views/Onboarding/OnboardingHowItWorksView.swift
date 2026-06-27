import SwiftUI

struct OnboardingHowItWorksView: View {
    let stepIndex: Int
    let onNext: () -> Void
    let onBack: () -> Void

    // (SF Symbol, badge tint, title, subtitle)
    private let steps: [(String, Color, String, String)] = [
        ("moon.zzz.fill", Theme.cry,      "wake up, not scroll up", "open this before anything else."),
        ("pencil.line",   Theme.confused, "pour your uncluttered thoughts", "write to yourself. your thoughts, your feelings, your morning."),
        ("lock.open.fill", Theme.happy,   "your apps unlock", "earn a sprout. start your day on your terms."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    OnboardingHeader(eyebrow: "here's how", title: "start with intention")

                    VStack(spacing: 22) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { _, s in
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: s.0)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                    .frame(width: 64, height: 64)
                                    .background(s.1.opacity(0.4))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.ink, lineWidth: 2))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(s.2)
                                        .font(AppFont.bodyBold(19))
                                        .foregroundStyle(Theme.ink)
                                    Text(s.3)
                                        .font(AppFont.accent(16))
                                        .foregroundStyle(Theme.inkFaint)
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 20)
            }

            OnboardingBottomBar(stepIndex: stepIndex, primaryTitle: "got it",
                                onBack: onBack, onPrimary: onNext)
        }
    }
}
