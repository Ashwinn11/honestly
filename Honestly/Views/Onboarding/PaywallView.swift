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
        ["block the apps that hijack you",
         "every prompt & gratitude question",
         "your journal, everywhere",
         "unlimited garden & backups"]
    }

    private var selectedPlan: MorningClubPlan? {
        subscriptionManager.plans.first { $0.id == selectedID } ?? subscriptionManager.plans.first
    }

    private var ctaTitle: String {
        (selectedPlan?.isLifetime ?? false) ? "unlock lifetime" : "start free trial"
    }

    var body: some View {
        ZStack {
            Theme.pageBackground
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    topBar
                    plantHero
                    headline
                    ratingRow
                    benefitList
                    planList
                    joinButton
                    legalRow
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .onAppear { if selectedID == nil { selectedID = subscriptionManager.plans.first?.id } }
        .onChange(of: subscriptionManager.plans.count) { _, _ in
            if selectedID == nil { selectedID = subscriptionManager.plans.first?.id }
        }
        .sheet(item: $legalDoc) { doc in
            if doc == .privacy { PrivacyPolicyView() } else { TermsOfServiceView() }
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
                restoreMessage = "No purchase found for this Apple ID."
            }
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
                    .background(Theme.card).clipShape(Circle())
                    .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 12)
    }

    private var plantHero: some View {
        PlantView(stage: .bloom, size: 120)
            .frame(width: 150, height: 150)
            .background(Theme.happy.opacity(0.5))
            .clipShape(Circle())
            .overlay(Circle().stroke(Theme.ink.opacity(0.08), lineWidth: 1.5))
    }

    private var headline: some View {
        VStack(spacing: 2) {
            Eyebrow("grow the whole garden", size: 20)
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
                    Text(b)
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

    private var joinButton: some View {
        VStack(spacing: 12) {
            Button(action: purchase) {
                VStack(spacing: 2) {
                    Text(purchasing ? "…" : ctaTitle)
                        .font(AppFont.button())
                    if let plan = selectedPlan, !purchasing {
                        Text("\(plan.priceLabel) · \(plan.unitLabel)")
                            .font(AppFont.caption(13))
                            .opacity(0.9)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.orange)
                .clipShape(Capsule(style: .continuous))
                .overlay(Capsule(style: .continuous).stroke(Theme.ink, lineWidth: Theme.borderWidth))
                .background(Capsule(style: .continuous).fill(Theme.ink).offset(y: Theme.shadowOffset))
            }
            .buttonStyle(.plain)

            Text("cancel anytime · nothing charged today")
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
            Button("Restore Purchases") { restore() }
            Text("·")
            Button("Privacy Policy") { legalDoc = .privacy }
            Text("·")
            Button("Terms of Service") { legalDoc = .terms }
        }
        .font(AppFont.caption(13))
        .foregroundStyle(Theme.inkFaint)
    }
}
