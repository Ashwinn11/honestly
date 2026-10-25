import SwiftUI
import Foundation

struct PaywallView: View {
    var onClose: () -> Void
    @Environment(PremiumManager.self) private var premium

    private enum Plan { case lifetime, monthly }
    @State private var selected: Plan = .lifetime
    @State private var purchasing = false
    @State private var restoring = false
    @State private var showPurchaseAlert = false
    @State private var legal: LegalDoc? = nil

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 0) {
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
            .overlay(alignment: .topTrailing) { closeButton }
            .capWidth(Metrics.maxContentWidth)
        }
        .alert("Purchase update", isPresented: $showPurchaseAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(premium.errorMessage ?? "")
        }
        .sheet(item: $legal) { LegalView(doc: $0) }
        .onAppear(perform: syncSelection)
        .onChange(of: premium.hasLifetime) { _, _ in syncSelection() }
        .onChange(of: premium.hasMonthly) { _, _ in syncSelection() }
    }

    // MARK: Close
    private var closeButton: some View {
        IconTileButton(icon: "xmark", size: 38, iconSize: 13) { onClose() }
            .padding(.horizontal, 20)
            .padding(.top, 8)
    }

    // MARK: Hero
    private var hero: some View {
        VStack(spacing: 10) {
            SunMark(size: 60).floaty()
                .background { SoftGlow(color: Palette.amber, opacity: 0.15, size: 210) }
            Text(loc: "Take your mornings back")
                .display(27, .bold)
                .multilineTextAlignment(.center)
            Text(loc: "Everything you need to keep the ritual.")
                .ui(13.5, .semibold, color: Palette.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Benefits — sun-disc bullets, no card
    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefitRow(Text(loc: "Block apps until you write"))
            benefitRow(Text(loc: "Daily prompts for every mood"))
            benefitRow(Text(loc: "Write your own affirmations & use widgets"))
            benefitRow(Text(loc: "Full history & iCloud backup"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func benefitRow(_ text: Text) -> some View {
        HStack(spacing: 11) {
            SunMark(size: 22, rays: false)
            text.ui(14.5, .semibold)
            Spacer(minLength: 0)
        }
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
                         sub: "Billed monthly",
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
                    Circle().strokeBorder(isSel ? Palette.amber : Palette.hairline, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSel { Circle().fill(Palette.amber).frame(width: 12, height: 12) }
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(loc: name).ui(16, .heavy)
                        Text(loc: badge).ui(9.5, .heavy, color: Palette.amberDeep)
                            .tracking(0.5)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Palette.amber.opacity(0.14), in: Capsule())
                    }
                    Text(loc: sub).ui(12.5, .semibold, color: Palette.inkSofter)
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
                .strokeBorder(isSel ? Palette.amber : Palette.ink.opacity(0.18), lineWidth: isSel ? 2 : 1.5))
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    // MARK: Footer — CTA + plan-aware reassurance + links
    private var footer: some View {
        VStack(spacing: 11) {
            ctaButton
            subNoteView
                .font(Fonts.ui(12, .semibold)).foregroundStyle(Palette.inkSofter)
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

    // The price must be interpolated directly into each `Text`/`PrimaryButton` literal (not built as
    // a plain String first) so the String Catalog can extract it as a translatable placeholder.
    @ViewBuilder private var ctaButton: some View {
        if purchasing {
            PrimaryButton(title: "Please wait…", enabled: false) {}
        } else if selected == .lifetime {
            let price = premium.lifetimePriceString
            if price.isEmpty {
                PrimaryButton(title: "Try loading purchase again") { purchase() }
            } else {
                PrimaryButton(title: "Unlock forever — \(price)") { purchase() }
            }
        } else {
            let price = premium.monthlyPriceString
            if price.isEmpty {
                PrimaryButton(title: "Continue") { purchase() }
            } else {
                PrimaryButton(title: "Continue — \(price)/mo") { purchase() }
            }
        }
    }

    private var subNoteView: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.shield")
                .accessibilityHidden(true)
            Text(loc: selected == .lifetime ? "One-time payment" : "Secure payment")
        }
    }

    // MARK: Actions
    private func syncSelection() {
        var available: [Plan] = []
        if premium.hasLifetime { available.append(.lifetime) }
        if premium.hasMonthly { available.append(.monthly) }
        if !available.contains(selected), let first = available.first { selected = first }
    }

    private func purchase() {
        guard !purchasing, !restoring else { return }
        purchasing = true
        Task {
            let ok = selected == .lifetime ? await premium.purchaseLifetime()
                                           : await premium.purchaseMonthly()
            purchasing = false
            if ok { Haptics.success(); onClose() }
            else if premium.errorMessage != nil { showPurchaseAlert = true }
        }
    }

    private func restore() {
        guard !restoring, !purchasing else { return }
        restoring = true
        Task {
            let ok = await premium.restore()
            restoring = false
            if ok { Haptics.success(); onClose() } else { showPurchaseAlert = true }
        }
    }

    private func footerLink(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(loc: title).ui(13.5, .bold, color: Palette.inkSofter) }
    }
    private var footerDot: some View {
        Circle().fill(Palette.inkSofter.opacity(0.45)).frame(width: 3, height: 3)
    }
}
