import SwiftUI

struct OnboardingFocusShieldView: View {
    let stepIndex: Int
    let onNext: () -> Void
    let onBack: () -> Void

    @EnvironmentObject var blockingManager: BlockingManager

    private let features: [(String, Color, String)] = [
        ("chart.pie.fill",        Theme.happy, "active from 4 AM until you check in"),
        ("checkmark.seal.fill",   Theme.confused, "unlocks the moment you finish your letter"),
        ("eye.slash.fill",        Theme.sad, "we never see what apps you open"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack(alignment: .topTrailing) {
                PlantView(stage: .mature, size: 120)
                    .padding(28)
                    .appCardStyle(fill: Theme.card)
                Mascot(kind: .clover, size: 30).offset(x: 8, y: -8)
            }
            .padding(.bottom, 8)

            OnboardingHeader(eyebrow: "the whole point —",
                             title: "let us guard your\nmorning peace",
                             alignment: .center,
                             titleSize: 32)
                .padding(.top, 16)

            VStack(spacing: 12) {
                ForEach(Array(features.enumerated()), id: \.offset) { _, f in
                    HStack(spacing: 14) {
                        Image(systemName: f.0)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 44, height: 44)
                            .background(f.1)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.ink, lineWidth: 2))
                        Text(f.2)
                            .font(AppFont.body(16))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                    }
                    .padding(14)
                    .appCardStyle(radius: 18)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            HStack(spacing: 6) {
                Image(systemName: "lock.open.fill").foregroundStyle(Theme.orange)
                Text("apps unlock the moment you finish.")
                    .font(AppFont.accent(17))
                    .foregroundStyle(Theme.orange)
            }
            .padding(.top, 16)

            Spacer()

            OnboardingBottomBar(stepIndex: stepIndex, primaryTitle: "enable focus shield",
                                secondaryTitle: "skip for now",
                                onBack: onBack,
                                onPrimary: {
                                    Task {
                                        await blockingManager.requestAuthorization()
                                        blockingManager.setBlockingEnabled(true)
                                        onNext()
                                    }
                                },
                                onSecondary: onNext)
        }
    }
}
