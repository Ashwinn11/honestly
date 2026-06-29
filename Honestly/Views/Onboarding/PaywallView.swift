import SwiftUI

/// Morning Club paywall. Plans, titles, and prices are rendered live from
/// the RevenueCat offering (`subscriptionManager.plans`) — nothing hardcoded.
struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    let onDismiss: () -> Void

    @State private var selectedID: String?
    @State private var purchasing = false
    @State private var legalDoc: LegalDoc?
    @State private var restoreMessage: String?

    private var benefits: [String] {
        ["reclaim the time the scroll steals",
         "every prompt to clear your head",
         "your mornings, kept & synced everywhere",
         "and your garden keeps growing"]
    }

    private var selectedPlan: MorningClubPlan? {
        subscriptionManager.plans.first { $0.id == selectedID } ?? subscriptionManager.plans.first
    }

    private var ctaTitle: String {
        guard let plan = selectedPlan else { return L("subscribe") }
        if plan.isLifetime {
            return String(format: L("get lifetime for %@"), plan.priceLabel)
        }
        return String(format: L("subscribe for %@/%@"), plan.priceLabel, plan.shortPeriod)
    }

    var body: some View {
        ZStack {
            Theme.pageBackground
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    topBar
                    appBadge
                    headline
                    ratingRow
                    benefitList
                    planList
                    joinButton
                    legalRow
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .contentColumn()
            }
        }
        .onAppear { if selectedID == nil { selectedID = subscriptionManager.plans.first?.id } }
        .onChange(of: subscriptionManager.plans.count) { _, _ in
            if selectedID == nil { selectedID = subscriptionManager.plans.first?.id }
        }
        .sheet(item: $legalDoc) { doc in
            Group {
                if doc == .privacy { PrivacyPolicyView() } else { TermsOfServiceView() }
            }
            .columnSheet()
        }
        .alert("Restore Purchases", isPresented: Binding(get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } })) {
            Button("OK", role: .cancel) { restoreMessage = nil }
        } message: {
            Text(restoreMessage ?? "")
        }
    }

    private func restore() {
        Task {
            try? await subscriptionManager.restore()
            if subscriptionManager.isPremium {
                onDismiss()
            } else {
                restoreMessage = L("No purchase found for this Apple ID.")
            }
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark").headerCircle()
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 12)
    }

    private var appBadge: some View {
        VStack(spacing: 12) {
            Image("WelcomeHero")
                .resizable().scaledToFit()
                .frame(width: AppLayout.s(96), height: AppLayout.s(96))
                .padding(AppLayout.s(8))
                .background(Theme.orange)
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.s(24), style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: AppLayout.s(24), style: .continuous).stroke(Theme.ink, lineWidth: Theme.borderWidth))
                .background(RoundedRectangle(cornerRadius: AppLayout.s(24), style: .continuous).fill(Theme.ink).offset(y: Theme.shadowOffset))
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundStyle(Theme.orange)
                Text("MORNING CLUB")
                    .font(AppFont.bodyBold(15))
                    .tracking(1.5)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 18).padding(.vertical, 9)
            .background(Theme.ink)
            .clipShape(Capsule())
        }
    }

    /// The same hours/year figure shown on the cost screen, pointed forward as
    /// the payoff. Reads the scroll estimate the user set during onboarding;
    /// falls back to the 30-min default when none was saved (e.g. older installs).
    private var hoursReclaimed: Int {
        let store = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
        let minutes = store?.object(forKey: AppConstants.keyScrollMinutes) as? Int ?? 30
        return max(1, minutes * 365 / 60)
    }

    private var headline: some View {
        VStack(spacing: 2) {
            Eyebrow(String(format: L("reclaim ~%lld hours a year"), hoursReclaimed), size: 20)
            Text("Honestly Premium")
                .font(AppFont.display(28))
                .foregroundStyle(Theme.ink)
        }
    }

    private var ratingRow: some View {
        HStack(spacing: 7) {
            Text("★★★★★").font(AppFont.caption(14)).foregroundStyle(Theme.orange).tracking(1)
            Text("4.9 · 12,000 calmer mornings")
                .font(AppFont.bodySemibold(13))
                .foregroundStyle(Theme.inkFaint)
        }
    }

    private var benefitList: some View {
        VStack(alignment: .leading, spacing: 11) {
            ForEach(Array(benefits.enumerated()), id: \.offset) { _, b in
                HStack(spacing: 11) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.orange)
                    Text(LocalizedStringKey(b))
                        .font(AppFont.body(16))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    @ViewBuilder private var planList: some View {
        if subscriptionManager.plans.isEmpty {
            ProgressView().tint(Theme.orange).padding(.vertical, 24)
        } else {
            VStack(spacing: 12) {
                ForEach(subscriptionManager.plans) { plan in
                    planRow(plan)
                }
            }
        }
    }

    private func planRow(_ plan: MorningClubPlan) -> some View {
        let isSelected = selectedPlan?.id == plan.id
        return Button { selectedID = plan.id } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title)
                        .font(AppFont.bodyBold(17))
                        .foregroundStyle(Theme.ink)
                    Text(plan.subtitle)
                        .font(AppFont.accent(15))
                        .foregroundStyle(Theme.inkFaint)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(plan.priceLabel)
                        .font(AppFont.bodyBold(17))
                        .foregroundStyle(Theme.ink)
                    Text(plan.unitLabel)
                        .font(AppFont.caption(12))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            .padding(16)
            .appCardStyle(fill: isSelected ? Theme.orange.opacity(0.14) : Theme.card,
                          borderColor: isSelected ? Theme.orange : Theme.ink)
        }
        .buttonStyle(.plain)
    }

    private var reassurance: String {
        (selectedPlan?.isLifetime ?? false)
            ? L("secure checkout · one-time purchase")
            : L("cancel anytime · secure checkout")
    }

    private var joinButton: some View {
        VStack(spacing: 10) {
            Button(action: purchase) {
                Text(purchasing ? "…" : ctaTitle)
                    .font(AppFont.button())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Theme.orange)
                    .clipShape(Capsule(style: .continuous))
                    .overlay(Capsule(style: .continuous).stroke(Theme.ink, lineWidth: Theme.borderWidth))
                    .background(Capsule(style: .continuous).fill(Theme.ink).offset(y: Theme.shadowOffset))
            }
            .buttonStyle(.plain)

            Text(reassurance)
                .font(AppFont.body(13))
                .foregroundStyle(Theme.inkFaint)
        }
        .padding(.top, 4)
    }

    private func purchase() {
        guard let plan = selectedPlan, !purchasing else { return }
        purchasing = true
        Task {
            try? await subscriptionManager.purchase(plan)
            purchasing = false
            if subscriptionManager.isPremium { onDismiss() }
        }
    }

    private var legalRow: some View {
        HStack(spacing: 16) {
            Button("restore") { restore() }
            Text("·")
            Button("policy") { legalDoc = .privacy }
            Text("·")
            Button("terms") { legalDoc = .terms }
        }
        .font(AppFont.caption(13))
        .foregroundStyle(Theme.inkFaint)
    }
}
