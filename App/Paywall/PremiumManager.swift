import Foundation
import Observation
import RevenueCat

/// RevenueCat wrapper for the lifetime "Honestly Premium" unlock. Fails soft everywhere so the
/// app doesn't get stuck if the network or the store is unavailable.
@MainActor
@Observable
final class PremiumManager {
    var isPremium = false
    var offerings: Offerings? = nil
    var purchasing = false

    /// Call once at launch, before any other Purchases use.
    func configure() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: AppConfig.revenueCatAPIKey)
        Task { await refresh(); await loadOfferings() }
    }

    func refresh() async {
        guard let info = try? await Purchases.shared.customerInfo() else { return }
        isPremium = info.entitlements[AppConfig.entitlementID]?.isActive == true
    }

    func loadOfferings() async {
        offerings = try? await Purchases.shared.offerings()
    }

    /// The lifetime package, tolerant of how the offering is configured.
    var lifetimePackage: Package? {
        guard let current = offerings?.current else { return nil }
        return current.availablePackages.first { $0.identifier == AppConfig.lifetimePackageID }
            ?? current.lifetime
            ?? current.availablePackages.first
    }

    var priceString: String { lifetimePackage?.storeProduct.localizedPriceString ?? "" }

    @discardableResult
    func purchase(_ package: Package) async -> Bool {
        purchasing = true
        defer { purchasing = false }
        guard let result = try? await Purchases.shared.purchase(package: package), !result.userCancelled
        else { return false }
        isPremium = result.customerInfo.entitlements[AppConfig.entitlementID]?.isActive == true
        return isPremium
    }

    @discardableResult
    func restore() async -> Bool {
        guard let info = try? await Purchases.shared.restorePurchases() else { return false }
        isPremium = info.entitlements[AppConfig.entitlementID]?.isActive == true
        return isPremium
    }
}
