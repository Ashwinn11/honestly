import SwiftUI
import Foundation

struct PaywallView: View {
    var onClose: () -> Void
    /// Onboarding goes on to choosing the apps after a purchase; elsewhere a purchase just closes.
    var onPurchased: (() -> Void)? = nil
    @Environment(PremiumManager.self) private var premium
    @Environment(JournalStore.self) private var store
    @Environment(\.locale) private var locale

    private enum Plan { case lifetime, annual, monthly }
    @State private var selected: Plan = .lifetime
    @State private var purchasing = false
    @State private var restoring = false
    @State private var showPurchaseAlert = false
    @State private var legal: LegalDoc? = nil

    var body: some View {
        ZStack {
            PaperBackground()
            GeometryReader { geo in
                ScrollView {
                    // The footer is part of the page, not pinned: it closes the page when everything
                    // fits, and follows the plans when they scroll.
                    VStack(spacing: 0) {
                        Spacer(minLength: 10)
                        VStack(spacing: 18) {
                            hero
                            benefitsCard
                            reviewCard
                            planPicker
                        }
                        .padding(.horizontal, 22)
                        Spacer(minLength: 22)
                        footer
                    }
                    .frame(minHeight: geo.size.height)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
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
        .onChange(of: premium.hasAnnual) { _, _ in syncSelection() }
        .onChange(of: premium.hasLifetime) { _, _ in syncSelection() }
        .onChange(of: premium.hasMonthly) { _, _ in syncSelection() }
    }

    // MARK: Close
    private var closeButton: some View {
        IconTileButton.close { onClose() }
            .padding(.horizontal, 20)
            .padding(.top, 8)
    }

    // MARK: Hero — this month's book, titled by how their mornings start; the list says the rest
    private var hero: some View {
        VStack(spacing: 14) {
            MonthBookCover(book: MonthBook.containing(Date(), in: store), width: 84)
                .rotationEffect(.degrees(-4))
                .shadow(color: Palette.ink.opacity(0.12), radius: 12, x: 0, y: 7)
                .background { SoftGlow(color: Palette.sunDisc, opacity: 0.2, size: 240) }
                .accessibilityHidden(true)
            Text(loc: MorningAnswer.saved.first?.paywallTitle ?? "Take your mornings back")
                .display(24, .bold)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Benefits — sun-disc bullets, no card; what each one does for them
    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefitRow(Text(loc: "Your apps wait until you’ve written"))
            backupBenefit
            benefitRow(Text(loc: "Your own prompts and affirmations"))
            benefitRow(Text(loc: "Affirmations on your widgets"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    /// Once this month's book has pages, the backup point names it — their book, not a book.
    private var backupBenefit: some View {
        let book = MonthBook.containing(Date(), in: store)
        return benefitRow(book.entries.isEmpty
            ? Text(loc: "Every month’s book, backed up to iCloud")
            : Text("Your \(HDate.monthName(book.firstOfMonth)) book and every one after it, backed up to iCloud"))
    }

    private func benefitRow(_ text: Text) -> some View {
        HStack(spacing: 11) {
            SunMark(size: 22, rays: false)
            text.ui(13.5, .semibold)
            Spacer(minLength: 0)
        }
    }

    // MARK: Review — one real App Store review, where the decision is made
    @ViewBuilder private var reviewCard: some View {
        if let quote = AppContent.socialProof.quotes.first {
            VStack(alignment: .leading, spacing: 7) {
                Text("\(Text(reviewText(quote))) \(reviewStars)")
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                if locale.language.languageCode?.identifier != "en" {
                    Text(loc: "Translated from English")
                        .ui(11, .medium, color: Palette.inkSofter)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .softCard(padding: 14)
        }
    }

    private let reviewAttributionSize: CGFloat = 12

    private var reviewStars: Text {
        let fontSize = DesignScale.s(reviewAttributionSize)
        let starSize = (UIFont(name: "Manrope-SemiBold", size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize, weight: .semibold)).capHeight
        let renderer = ImageRenderer(content: HStack(spacing: DesignScale.s(2)) {
            ForEach(0..<5, id: \.self) { _ in
                InkGlyph(kind: .star, size: starSize, fill: Palette.glyphGold, lineWidth: DesignScale.s(0.8))
            }
        }.fixedSize())
        renderer.scale = UIScreen.main.scale
        if let image = renderer.uiImage {
            return Text(Image(uiImage: image))
        }
        return Text(verbatim: "★★★★★").font(Fonts.ui(reviewAttributionSize, .semibold)).foregroundColor(Palette.glyphGold)
    }

    private func reviewText(_ quote: SocialProof.Quote) -> AttributedString {
        var text = AttributedString("“" + L10n.localized(quote.text) + "” ")
        text.font = Fonts.ui(13.5, .semibold)
        text.foregroundColor = Palette.ink
        var author = AttributedString("—\u{00A0}" + quote.author)
        author.font = Fonts.ui(reviewAttributionSize, .semibold)
        author.foregroundColor = Palette.inkSofter
        text.append(author)
        return text
    }

    // MARK: Plan picker — Lifetime (the default), Yearly (anchored against twelve monthly
    // payments), Monthly
    @ViewBuilder private var planPicker: some View {
        VStack(spacing: 12) {
            if premium.hasLifetime {
                planCard(.lifetime, name: "Lifetime", badge: Text(loc: "BEST VALUE"),
                         sub: Text(loc: "Pay once · yours forever"),
                         price: premium.lifetimePriceString, period: nil)
            }
            if premium.hasAnnual {
                planCard(.annual, name: "Yearly",
                         badge: premium.annualSavingsPercent.map { Text("Save \($0)%") },
                         sub: premium.annualPerMonthString.isEmpty
                            ? Text(loc: "Billed yearly")
                            : Text("\(premium.annualPerMonthString)/mo, billed yearly"),
                         price: premium.annualPriceString, period: "/yr",
                         anchor: premium.annualSavingsPercent == nil ? nil : premium.monthlyForAYearString)
            }
            if premium.hasMonthly {
                planCard(.monthly, name: "Monthly", badge: Text(loc: "FLEXIBLE"),
                         sub: Text(loc: "Billed monthly"),
                         price: premium.monthlyPriceString, period: "/mo")
            }
        }
    }

    /// One plan. `anchor` is the price it's measured against, struck through above its own.
    private func planCard(_ plan: Plan, name: String, badge: Text?, sub: Text,
                          price: String, period: String?, anchor: String? = nil) -> some View {
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
                        if let badge {
                            badge.ui(9.5, .heavy, color: Palette.amberDeep)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Palette.amber.opacity(0.14), in: Capsule())
                        }
                    }
                    sub.ui(12.5, .semibold, color: Palette.inkSofter)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    if let anchor, !anchor.isEmpty {
                        Text(verbatim: anchor)
                            .ui(12, .bold, color: Palette.inkSofter)
                            .strikethrough(color: Palette.inkSofter)
                    }
                    HStack(spacing: 1) {
                        Text(verbatim: price.isEmpty ? "—" : price).ui(17, .heavy)
                        if let period { Text(loc: period).ui(12.5, .bold, color: Palette.inkSoft) }
                    }
                }
            }
            .padding(15)
            .background(isSel ? Palette.selectedFill : Palette.cream,
                        in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .strokeBorder(isSel ? Palette.amber : Palette.ink.opacity(0.18), lineWidth: isSel ? 2 : 1.5))
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    // MARK: Footer — CTA + plan-aware reassurance + links, at the end of the page
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
        } else if selected == .annual {
            let price = premium.annualPriceString
            if price.isEmpty {
                PrimaryButton(title: "Continue") { purchase() }
            } else {
                PrimaryButton(title: "Continue — \(price)/yr") { purchase() }
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
            Text(loc: selected == .lifetime ? "One-time payment" : "Cancel anytime in Settings")
        }
    }

    // MARK: Actions
    private func syncSelection() {
        var available: [Plan] = []
        if premium.hasLifetime { available.append(.lifetime) }
        if premium.hasAnnual { available.append(.annual) }
        if premium.hasMonthly { available.append(.monthly) }
        if !available.contains(selected), let first = available.first { selected = first }
    }

    private func purchase() {
        guard !purchasing, !restoring else { return }
        purchasing = true
        Task {
            let ok = switch selected {
            case .annual: await premium.purchaseAnnual()
            case .monthly: await premium.purchaseMonthly()
            case .lifetime: await premium.purchaseLifetime()
            }
            purchasing = false
            if ok { Haptics.success(); (onPurchased ?? onClose)() }
            else if premium.errorMessage != nil { showPurchaseAlert = true }
        }
    }

    private func restore() {
        guard !restoring, !purchasing else { return }
        restoring = true
        Task {
            let ok = await premium.restore()
            restoring = false
            if ok { Haptics.success(); (onPurchased ?? onClose)() } else { showPurchaseAlert = true }
        }
    }

    private func footerLink(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(loc: title).ui(13.5, .bold, color: Palette.inkSofter) }
    }
    private var footerDot: some View {
        Circle().fill(Palette.inkSofter.opacity(0.45)).frame(width: 3, height: 3)
    }
}

extension View {
    /// The paywall, presented from this screen. A sheet or cover can't show the app-wide one: the
    /// screen that presented it is busy presenting it, so SwiftUI holds the paywall back until it
    /// closes. Anything shown modally that has a locked control presents its own.
    func paywallCover(isPresented: Binding<Bool>) -> some View {
        fullScreenCover(isPresented: isPresented) {
            PaywallView(onClose: { isPresented.wrappedValue = false })
        }
    }
}
