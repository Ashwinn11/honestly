import Foundation
import RevenueCat
import Combine

/// A purchasable plan, fully derived from a RevenueCat `Package`.
/// Nothing here is hardcoded — title, price, and period come from StoreKit via RevenueCat.
struct MorningClubPlan: Identifiable {
    let package: Package

    var id: String { package.identifier }

    /// Localized price string straight from the store ("$29.99", "₹2,499", …).
    var priceLabel: String { package.storeProduct.localizedPriceString }

    /// True for the lifetime plan. Keyed off RevenueCat's package type (how
    /// `fetchPlans` tells the two plans apart) rather than the StoreKit product
    /// type, which varies by how the lifetime product is configured.
    var isLifetime: Bool { package.packageType == .lifetime }

    // Morning Club only sells two plans — monthly + lifetime (see `fetchPlans`) —
    // so the period copy below only covers those two cases.

    /// "one-time" for lifetime, otherwise the monthly cadence.
    var unitLabel: String { isLifetime ? L("one-time") : L("per month") }

    /// Compact period suffix for the CTA ("$4.99/mo"). Empty for lifetime.
    var shortPeriod: String { isLifetime ? "" : L("mo") }

    var title: String { isLifetime ? L("Lifetime") : L("Monthly") }

    var subtitle: String { isLifetime ? L("pay once, yours forever.") : L("billed monthly") }
}

class SubscriptionManager: ObservableObject {
    @Published var isPremium: Bool = false
    @Published private(set) var plans: [MorningClubPlan] = []
    @Published private(set) var isLoadingPlans = false

    private let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)

    init() {
        isPremium = defaults?.bool(forKey: AppConstants.keyIsPremium) ?? false
    }

    func configure(apiKey: String) {
        Purchases.configure(withAPIKey: apiKey)
        checkStatus()
        fetchPlans()
    }

    /// Pull the current offering's packages and map them to display plans.
    /// Morning Club only sells monthly + lifetime; filter to those and put
    /// lifetime first to match the paywall layout.
    func fetchPlans() {
        isLoadingPlans = true
        Purchases.shared.getOfferings { [weak self] offerings, _ in
            let packages = (offerings?.current?.availablePackages ?? [])
                .filter { $0.packageType == .lifetime || $0.packageType == .monthly }
            let mapped = packages.map(MorningClubPlan.init)
                .sorted { lhs, _ in lhs.isLifetime }  // lifetime first
            DispatchQueue.main.async {
                self?.plans = mapped
                self?.isLoadingPlans = false
            }
        }
    }

    func checkStatus() {
        Purchases.shared.getCustomerInfo { [weak self] info, error in
            guard let self, error == nil else { return }
            let active = info?.entitlements[AppConstants.premiumEntitlementID]?.isActive == true
            DispatchQueue.main.async { self.apply(active) }
        }
    }

    func purchase(_ plan: MorningClubPlan) async throws {
        let result = try await Purchases.shared.purchase(package: plan.package)
        let active = result.customerInfo.entitlements[AppConstants.premiumEntitlementID]?.isActive == true
        await MainActor.run { self.apply(active) }
    }

    func restore() async throws {
        let info = try await Purchases.shared.restorePurchases()
        let active = info.entitlements[AppConstants.premiumEntitlementID]?.isActive == true
        await MainActor.run { self.apply(active) }
    }

    private func apply(_ active: Bool) {
        isPremium = active
        defaults?.set(active, forKey: AppConstants.keyIsPremium)
    }
}
