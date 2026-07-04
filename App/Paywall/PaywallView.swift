import SwiftUI

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

    private let benefits = [
        "Every mood prompt, personalized to you",
        "Your apps, quieted till you write",
        "Streaks, full history & cloud backup",
    ]

    private var goal: OnbGoal? { OnbGoal(rawValue: SharedState.onboardingGoal) }
    private var heroTitle: String { goal?.paywallHero ?? "Take your mornings back" }
    private var heroSub: String { "Everything you need to keep the ritual." }

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
        VStack(spacing: 10) {
            SunMark(size: 60).floaty()
                .background { SoftGlow(color: Palette.amber, opacity: 0.15, size: 210) }
            Text(heroTitle)
                .display(27, .bold)
                .multilineTextAlignment(.center)
            Text(heroSub)
                .ui(13.5, .semibold, color: Palette.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Benefits — sun-disc bullets, no card
    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(benefits, id: \.self) { b in
                HStack(spacing: 11) {
                    SunMark(size: 22, rays: false)
                    Text(b).ui(14.5, .semibold)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
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
            .background(isSel ? Color(hex: "FFF6E7") : Palette.cream,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSel ? Palette.amber : Palette.ink.opacity(0.18), lineWidth: isSel ? 2 : 1.5))
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
