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

    var lifetimePackage: Package? {
        guard let current = offerings?.current else { return nil }
        return current.availablePackages.first { $0.identifier == AppConfig.lifetimePackageID }
            ?? current.lifetime
            ?? current.availablePackages.first { $0.packageType == .lifetime }
    }

    var monthlyPackage: Package? {
        guard let current = offerings?.current else { return nil }
        return current.availablePackages.first { $0.identifier == AppConfig.monthlyPackageID }
            ?? current.monthly
            ?? current.availablePackages.first { $0.packageType == .monthly }
    }

    var hasLifetime: Bool { lifetimePackage != nil }
    var hasMonthly: Bool { monthlyPackage != nil }
    var lifetimePriceString: String { lifetimePackage?.storeProduct.localizedPriceString ?? "" }
    var monthlyPriceString: String { monthlyPackage?.storeProduct.localizedPriceString ?? "" }
    var lifetimePrice: Decimal? { lifetimePackage?.storeProduct.price }
    var monthlyPrice: Decimal? { monthlyPackage?.storeProduct.price }

    @discardableResult func purchaseLifetime() async -> Bool {
        guard let p = lifetimePackage else { return false }
        return await purchase(p)
    }
    @discardableResult func purchaseMonthly() async -> Bool {
        guard let p = monthlyPackage else { return false }
        return await purchase(p)
    }

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
