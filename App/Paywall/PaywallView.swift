import SwiftUI

/// "Honestly Premium" — the unlock, with selectable **Lifetime / Monthly** plans styled in the
/// app's language (paper, amber, Shantell). In `gate` mode it's the hard paywall shown as the last
/// step of onboarding (no dismiss); opened from Settings it gets a close button. The CTA and the
/// reassurance line beneath it change with the selected plan.
struct PaywallView: View {
    var gate: Bool = false
    var onClose: () -> Void
    @Environment(PremiumManager.self) private var premium

    private enum Plan { case lifetime, monthly }
    @State private var selected: Plan = .lifetime
    @State private var purchasing = false
    @State private var restoring = false
    @State private var showRestoreAlert = false
    @State private var legal: LegalDoc? = nil

    // Sell the vision, not the feature list — each line is the *impact* / who you become.
    private let benefits: [(String, String)] = [
        ("sunrise.fill", "Reclaim your mornings from the scroll"),
        ("leaf.fill",    "Start every day calmer and clearer"),
        ("flame.fill",   "Become someone who shows up — daily"),
        ("lock.fill",    "A private record of who you're becoming"),
    ]

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 0) {
                header
                GeometryReader { geo in
                    ScrollView {
                        VStack(spacing: 18) {
                            hero
                            benefitsCard
                            planPicker
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .frame(minHeight: geo.size.height, alignment: .center)  // center; scroll if tall
                    }
                }
                footer
            }
            .capWidth(Metrics.maxContentWidth)
        }
        .alert("No purchase found", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We couldn't find a previous purchase to restore on this Apple ID.")
        }
        .sheet(item: $legal) { LegalView(doc: $0) }
        .onAppear(perform: syncSelection)
        .onChange(of: premium.hasLifetime) { _, _ in syncSelection() }
        .onChange(of: premium.hasMonthly) { _, _ in syncSelection() }
    }

    // MARK: Header (close only when NOT the hard gate)
    private var header: some View {
        HStack {
            Spacer()
            if !gate { SoftCircleButton(icon: "xmark") { onClose() } }
        }
        .frame(height: 38)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: Hero
    private var hero: some View {
        VStack(spacing: 12) {
            SunMark(size: 68, stroke: Palette.amber, fill: Palette.amberLight).floaty()
            Text("Manifest 3× faster")
                .display(32, .heavy)
                .multilineTextAlignment(.center)
            Text("Reflect honestly each morning — and become who you're writing toward.")
                .ui(15, .semibold, color: Palette.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Benefits
    private var benefitsCard: some View {
        VStack(spacing: 11) {
            ForEach(Array(benefits.enumerated()), id: \.offset) { _, b in
                HStack(spacing: 14) {
                    Image(systemName: b.0)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.amber)
                        .frame(width: 38, height: 38)
                        .background(Palette.amber.opacity(0.12), in: Circle())
                    Text(b.1).ui(15, .bold)
                    Spacer()
                }
            }
        }
        .softCard(padding: 16)
    }

    // MARK: Plan picker — Lifetime (best value) + Monthly (optional)
    @ViewBuilder private var planPicker: some View {
        VStack(spacing: 12) {
            if premium.hasLifetime {
                planCard(.lifetime, name: "Lifetime", badge: "BEST VALUE",
                         sub: "Pay once · yours forever",
                         price: premium.lifetimePriceString, period: nil)
            }
            if premium.hasMonthly {
                planCard(.monthly, name: "Monthly", badge: "FLEXIBLE",
                         sub: "Billed monthly · cancel anytime",
                         price: premium.monthlyPriceString, period: "mo")
            }
        }
    }

    private func planCard(_ plan: Plan, name: String, badge: String, sub: String,
                          price: String, period: String?) -> some View {
        let isSel = selected == plan
        return Button {
            Haptics.select()
            withAnimation(Motion.snappy) { selected = plan }
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    Circle().stroke(isSel ? Palette.amber : Palette.hairline, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSel { Circle().fill(Palette.amber).frame(width: 12, height: 12) }
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(name).ui(16, .heavy)
                        Text(badge).ui(9.5, .heavy, color: Palette.amberDeep)
                            .tracking(0.5)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Palette.amber.opacity(0.14), in: Capsule())
                    }
                    Text(sub).ui(12.5, .semibold, color: Palette.inkSofter)
                }
                Spacer(minLength: 8)
                HStack(spacing: 1) {
                    Text(price.isEmpty ? "—" : price).ui(17, .heavy)
                    if let period { Text("/\(period)").ui(12.5, .bold, color: Palette.inkSoft) }
                }
            }
            .padding(15)
            .background(isSel ? Palette.amber.opacity(0.08) : .white,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSel ? Palette.amber : Palette.hairline, lineWidth: isSel ? 2 : 1.2))
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    // MARK: Footer — CTA + plan-aware reassurance + links
    private var footer: some View {
        VStack(spacing: 11) {
            PrimaryButton(title: ctaTitle, enabled: !purchasing) { purchase() }
            Text(subNote)
                .ui(12, .semibold, color: Palette.inkSofter)
                .multilineTextAlignment(.center)
            HStack(spacing: 18) {
                footerLink(restoring ? "Restoring…" : "Restore") { restore() }
                footerDot
                footerLink("Terms") { legal = .terms }
                footerDot
                footerLink("Privacy") { legal = .privacy }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 26)
    }

    private var ctaTitle: String {
        if purchasing { return "Please wait…" }
        switch selected {
        case .lifetime:
            let p = premium.lifetimePriceString
            return p.isEmpty ? "Unlock forever" : "Unlock forever · \(p)"
        case .monthly:
            let p = premium.monthlyPriceString
            return p.isEmpty ? "Continue" : "Continue · \(p)/mo"
        }
    }

    private var subNote: String {
        selected == .lifetime
            ? "One-time payment · no subscription, ever"
            : "Cancel anytime · secure checkout"
    }

    // MARK: Actions
    /// Keep the selection on an available plan (prefer lifetime). Runs on appear and when the
    /// offering loads/changes; never overrides a still-valid user choice.
    private func syncSelection() {
        var available: [Plan] = []
        if premium.hasLifetime { available.append(.lifetime) }
        if premium.hasMonthly { available.append(.monthly) }
        if !available.contains(selected), let first = available.first { selected = first }
    }

    private func purchase() {
        guard !purchasing else { return }
        purchasing = true
        Task {
            let ok = selected == .lifetime ? await premium.purchaseLifetime()
                                           : await premium.purchaseMonthly()
            purchasing = false
            if ok { Haptics.success(); onClose() }
        }
    }

    private func restore() {
        guard !restoring else { return }
        restoring = true
        Task {
            let ok = await premium.restore()
            restoring = false
            if ok { Haptics.success(); onClose() } else { showRestoreAlert = true }
        }
    }

    private func footerLink(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).ui(13.5, .bold, color: Palette.inkSofter) }
    }
    private var footerDot: some View {
        Circle().fill(Palette.inkSofter.opacity(0.45)).frame(width: 3, height: 3)
    }
}
