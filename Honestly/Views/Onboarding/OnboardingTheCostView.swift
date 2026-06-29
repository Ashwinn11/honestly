import SwiftUI

/// Loss-aversion beat in the "reclaim, then calm" arc: name the cost of the
/// morning scroll (hours/year derived from the user's own scroll-time answer),
/// then immediately offer the way back.
struct OnboardingTheCostView: View {
    let stepIndex: Int
    let scrollMinutes: Int
    let onNext: () -> Void
    let onBack: () -> Void

    /// Hours per year lost to the morning scroll, from the user's daily minutes.
    private var hoursPerYear: Int { max(1, scrollMinutes * 365 / 60) }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    OnboardingHeader(eyebrow: "here's the honest part —",
                                     title: "your mornings are quietly leaking.")

                    // The cost — compact stat card
                    VStack(spacing: 2) {
                        Text("\(hoursPerYear)")
                            .font(AppFont.display(58))
                            .foregroundStyle(Theme.orange)
                        Text("hours a year")
                            .font(AppFont.accent(20))
                            .foregroundStyle(Theme.ink)
                        Rectangle().fill(Theme.inkGhost)
                            .frame(height: 1)
                            .padding(.horizontal, 24).padding(.vertical, 10)
                        Text("lost to the morning scroll — about \(scrollMinutes) minutes, every single day.")
                            .font(AppFont.body(14))
                            .foregroundStyle(Theme.inkFaint)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .appCardStyle(fill: Theme.card)

                    // The way back — plain, no card, centered
                    VStack(spacing: 8) {
                        Eyebrow("the good news —", size: 18)
                        Text("you can take them back.")
                            .font(AppFont.cardTitle(24))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                        Text("three quiet minutes with Honestly, and the rest of the morning is yours again — calm, clear, present.")
                            .font(AppFont.body(15))
                            .foregroundStyle(Theme.inkFaint)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            }

            OnboardingBottomBar(stepIndex: stepIndex, primaryTitle: "reclaim my mornings",
                                onBack: onBack, onPrimary: onNext)
        }
    }
}
