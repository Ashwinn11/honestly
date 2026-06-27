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

    private var benefits: [(String, Color, String)] {
        [("lock.shield.fill", Theme.awful,    "block the apps that hijack you"),
         ("sunrise.fill",     Theme.happy,    "mornings on autopilot"),
         ("book.fill",        Theme.confused, "your journal, everywhere"),
         ("icloud.fill",      Theme.cry,      "never lose an entry")]
    }

    private var selectedPlan: MorningClubPlan? {
        subscriptionManager.plans.first { $0.id == selectedID } ?? subscriptionManager.plans.first
    }

    var body: some View {
        ZStack {
            Theme.pageBackground
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    topBar
                    appBadge
                    headline
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

    private var appBadge: some View {
        VStack(spacing: 12) {
            Image("WelcomeHero")
                .resizable().scaledToFit()
                .frame(width: 96, height: 96)
                .padding(8)
                .background(Theme.orange)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.ink, lineWidth: Theme.borderWidth))
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.ink).offset(y: Theme.shadowOffset))
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

    private var headline: some View {
        VStack(spacing: 4) {
            Eyebrow("this is for", size: 22)
            Text("your mornings.")
                .font(AppFont.display(34))
                .foregroundStyle(Theme.ink)
        }
    }

    private var benefitList: some View {
        VStack(spacing: 16) {
            ForEach(Array(benefits.enumerated()), id: \.offset) { _, b in
                HStack(spacing: 14) {
                    ColorIconBadge(icon: b.0, color: b.1, size: 44)
                    Text(b.2)
                        .font(AppFont.bodyBold(18))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 4)
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
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(AppFont.cardTitle(24))
                            .foregroundStyle(Theme.ink)
                        if plan.isLifetime {
                            Text("one-time")
                                .font(AppFont.accent(14))
                                .foregroundStyle(Theme.orange)
                                .padding(.horizontal, 10).padding(.vertical, 3)
                                .overlay(Capsule().stroke(Theme.orange, lineWidth: 1.5))
                        }
                    }
                    Text(plan.subtitle)
                        .font(AppFont.body(15))
                        .foregroundStyle(Theme.inkFaint)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.priceLabel)
                        .font(AppFont.title(22))
                        .foregroundStyle(Theme.ink)
                    Text(plan.unitLabel)
                        .font(AppFont.caption(13))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            .padding(18)
            .appCardStyle(fill: isSelected ? Theme.orange.opacity(0.14) : Theme.card,
                          borderColor: isSelected ? Theme.orange : Theme.ink)
        }
        .buttonStyle(.plain)
    }

    private var joinButton: some View {
        VStack(spacing: 12) {
            Button(action: purchase) {
                VStack(spacing: 2) {
                    Text(purchasing ? "…" : "join the club")
                        .font(AppFont.button())
                    if let plan = selectedPlan, !purchasing {
                        Text("\(plan.priceLabel) · \(plan.unitLabel)")
                            .font(AppFont.caption(13))
                            .opacity(0.9)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.orange)
                .clipShape(Capsule(style: .continuous))
                .overlay(Capsule(style: .continuous).stroke(Theme.ink, lineWidth: Theme.borderWidth))
                .background(Capsule(style: .continuous).fill(Theme.ink).offset(y: Theme.shadowOffset))
            }
            .buttonStyle(.plain)

            Text("instant full access · cancel anytime.")
                .font(AppFont.bodySemibold(14))
                .foregroundStyle(Theme.ink)
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
