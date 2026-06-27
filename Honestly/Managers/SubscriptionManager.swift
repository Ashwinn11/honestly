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

    /// True for a one-time / non-subscription purchase (e.g. lifetime).
    var isLifetime: Bool { package.storeProduct.productType == .nonConsumable }

    /// "one-time" or the subscription period ("per month", "per year", …).
    var unitLabel: String {
        guard let period = package.storeProduct.subscriptionPeriod else { return "one-time" }
        switch period.unit {
        case .day:   return period.value == 1 ? "per day" : "every \(period.value) days"
        case .week:  return period.value == 1 ? "per week" : "every \(period.value) weeks"
        case .month: return period.value == 1 ? "per month" : "every \(period.value) months"
        case .year:  return period.value == 1 ? "per year" : "every \(period.value) years"
        @unknown default: return ""
        }
    }

    /// Display title from RevenueCat's package type, falling back to the store product name.
    var title: String {
        switch package.packageType {
        case .lifetime: return "Lifetime"
        case .annual:   return "Yearly"
        case .monthly:  return "Monthly"
        case .weekly:   return "Weekly"
        default:        return package.storeProduct.localizedTitle
        }
    }

    var subtitle: String {
        isLifetime ? "pay once, yours forever." : "billed \(unitLabel.replacingOccurrences(of: "per ", with: ""))"
    }
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
