import SwiftUI

/// "Honestly Premium" — the lifetime unlock, styled in the app's own language (paper, amber,
/// Shantell). In `gate` mode it's the hard paywall shown after onboarding (premium-only app).
struct PaywallView: View {
    var gate: Bool = false
    var onClose: () -> Void
    @Environment(PremiumManager.self) private var premium
    @State private var restoring = false
    @State private var showRestoreAlert = false
    @State private var legal: LegalDoc? = nil

    private let benefits: [(String, String)] = [
        ("infinity", "Your whole history"),
        ("calendar", "The full mood calendar"),
        ("chart.bar.fill", "Every insight & streak stat"),
        ("icloud.fill", "Private iCloud backup"),
    ]

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    // Hard paywall: no dismiss in gate mode. The X only exists when opened from
                    // Settings ("Manage subscription"), not as the premium-only onboarding gate.
                    if !gate {
                        SoftCircleButton(icon: "xmark") { onClose() }
                    }
                }
                .frame(height: 38)
                .padding(.horizontal, 20)
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 22) {
                        VStack(spacing: 14) {
                            SunMark(size: 76, stroke: Palette.amber, fill: Palette.amberLight)
                                .floaty()
                            Text("Honestly Premium").display(32, .heavy)
                            Text("Keep every morning — forever.")
                                .ui(15.5, .semibold, color: Palette.inkSoft)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 12)

                        VStack(spacing: 12) {
                            ForEach(Array(benefits.enumerated()), id: \.offset) { i, b in
                                HStack(spacing: 14) {
                                    Image(systemName: b.0)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Palette.amber)
                                        .frame(width: 40, height: 40)
                                        .background(Palette.amber.opacity(0.12), in: Circle())
                                    Text(b.1).ui(15.5, .bold)
                                    Spacer()
                                }
                                .staggeredAppear(index: i)
                            }
                        }
                        .softCard(padding: 18)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)
                }

                VStack(spacing: 14) {
                    PrimaryButton(title: premium.priceString.isEmpty
                                  ? "Unlock forever" : "Unlock forever for \(premium.priceString)") {
                        Task {
                            if let pkg = premium.lifetimePackage, await premium.purchase(pkg) {
                                Haptics.success(); onClose()
                            }
                        }
                    }
                    HStack(spacing: 18) {
                        footerLink(restoring ? "Restoring…" : "Restore") {
                            guard !restoring else { return }
                            restoring = true
                            Task {
                                let ok = await premium.restore()
                                restoring = false
                                if ok { Haptics.success(); onClose() } else { showRestoreAlert = true }
                            }
                        }
                        footerDot
                        footerLink("Terms") { legal = .terms }
                        footerDot
                        footerLink("Privacy") { legal = .privacy }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
        }
        .alert("No purchase found", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We couldn't find a previous purchase to restore on this Apple ID.")
        }
        .sheet(item: $legal) { LegalView(doc: $0) }
    }

    private func footerLink(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).ui(13.5, .bold, color: Palette.inkSofter) }
    }
    private var footerDot: some View {
        Circle().fill(Palette.inkSofter.opacity(0.45)).frame(width: 3, height: 3)
    }
}
