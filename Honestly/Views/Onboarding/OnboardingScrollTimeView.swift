import SwiftUI

struct OnboardingScrollTimeView: View {
    let stepIndex: Int
    @Binding var minutes: Int
    let onNext: () -> Void
    let onBack: () -> Void

    // (label, minutes, blurb, SF Symbol, badge tint)
    private let options: [(String, Int, String, String, Color)] = [
        ("under 5 min", 5,  "pretty mindful.", "leaf.fill",          Theme.confused),
        ("5–15 min",    15, "a common morning scroll.",       "iphone",             Theme.happy),
        ("15–30 min",   30, "deep in the feed.",              "hourglass",          Theme.sad),
        ("30+ min",     60, "it adds up fast.",               "exclamationmark.bubble.fill", Theme.awful),
    ]

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
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
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            }

            OnboardingBottomBar(stepIndex: stepIndex, primaryTitle: "that's my pace →",
                                onBack: onBack, onPrimary: onNext)
        }
    }

    private func card(_ opt: (String, Int, String, String, Color)) -> some View {
        let selected = minutes == opt.1
        return Button { minutes = opt.1 } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: opt.3)
                    .font(.system(size: AppLayout.s(22), weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: AppLayout.s(50), height: AppLayout.s(50))
                    .background(opt.4)
                    .clipShape(RoundedRectangle(cornerRadius: AppLayout.s(15), style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: AppLayout.s(15), style: .continuous).stroke(Theme.ink, lineWidth: AppLayout.s(2)))
                Text(LocalizedStringKey(opt.0))
                    .font(AppFont.bodyBold(19))
                    .foregroundStyle(Theme.ink)
                Text(LocalizedStringKey(opt.2))
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
