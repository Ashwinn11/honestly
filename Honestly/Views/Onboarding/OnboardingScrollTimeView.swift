import SwiftUI

struct OnboardingScrollTimeView: View {
    let stepIndex: Int
    @Binding var minutes: Int
    let onNext: () -> Void
    let onBack: () -> Void

    // (label, minutes, blurb, plant stage shown)
    private let options: [(String, Int, String, PlantStage)] = [
        ("under 5 min", 5,  "you're already pretty mindful.", .sprout),
        ("5–15 min",    15, "a common morning scroll.",       .young),
        ("15–30 min",   30, "deep in the feed.",              .mature),
        ("30+ min",     60, "it adds up fast.",               .flowering),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    OnboardingHeader(eyebrow: "be honest —",
                                     title: "how long do you scroll before you open honestly?",
                                     subtitle: "this helps us understand your morning.")

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(options, id: \.1) { opt in
                            card(opt)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 20)
            }

            OnboardingBottomBar(stepIndex: stepIndex, primaryTitle: "that's my pace →",
                                onBack: onBack, onPrimary: onNext)
        }
    }

    private func card(_ opt: (String, Int, String, PlantStage)) -> some View {
        let selected = minutes == opt.1
        return Button { minutes = opt.1 } label: {
            VStack(alignment: .leading, spacing: 10) {
                PlantView(stage: opt.3, size: 56)
                Text(opt.0)
                    .font(AppFont.bodyBold(19))
                    .foregroundStyle(Theme.ink)
                Text(opt.2)
                    .font(AppFont.accent(15))
                    .foregroundStyle(Theme.inkFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .appCardStyle(fill: selected ? Theme.orange.opacity(0.12) : Theme.card,
                          borderColor: selected ? Theme.orange : Theme.ink)
        }
        .buttonStyle(.plain)
    }
}
