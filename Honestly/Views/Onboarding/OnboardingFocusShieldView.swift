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

            Image("art-journal")
                .resizable().scaledToFit()
                .frame(width: 180, height: 180)
                .padding(.bottom, 2)

            OnboardingHeader(eyebrow: "the whole point —",
                             title: "let us guard your morning peace",
                             alignment: .center)
                .padding(.top, 16)

            VStack(spacing: 10) {
                ForEach(Array(features.enumerated()), id: \.offset) { _, f in
                    HStack(spacing: 13) {
                        Image(systemName: f.0)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 40, height: 40)
                            .background(f.1)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Theme.ink, lineWidth: 2))
                        Text(f.2)
                            .font(AppFont.body(15))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 13).padding(.vertical, 11)
                    .appCardStyle(radius: 16)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

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
