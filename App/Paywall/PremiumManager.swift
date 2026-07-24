import Foundation
import Observation
import RevenueCat

/// RevenueCat wrapper for the lifetime "Honestly Premium" unlock. Fails soft everywhere so the
/// app doesn't get stuck if the network or the store is unavailable.
///
/// Premium is a one-time lifetime purchase, so the flag only ever moves in one direction:
/// `isPremium` seeds from the app-group mirror (correct from the first frame — offline, mid-launch,
/// before RevenueCat resolves), RevenueCat is consulted only while it's still false, and `ratchet`
/// is the single place it flips on. Nothing ever writes it back to false — a fresh install starts
/// false and "Restore purchases" re-ratchets it on a new device.
@MainActor
@Observable
final class PremiumManager {
    private(set) var isPremium = false
    var offerings: Offerings? = nil

    func configure() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: AppConfig.revenueCatAPIKey)
        Task {
            if !isPremium { await refresh() }   // once premium, the entitlement is never re-checked
            await loadOfferings()
        }
    }

    func refresh() async {
        guard !isPremium else { return }
        guard let info = try? await Purchases.shared.customerInfo() else { return }
        ratchet(info)
    }

    /// The single write path for premium: flips on once and mirrors into the app group in the same
    /// breath (the background monitor extension gates shielding on that mirror). No downgrade path.
    private func ratchet(_ info: CustomerInfo) {
        guard !isPremium, info.entitlements[AppConfig.entitlementID]?.isActive == true else { return }
        isPremium = true
        SharedState.premiumActive = true
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
        guard let result = try? await Purchases.shared.purchase(package: package), !result.userCancelled
        else { return false }
        ratchet(result.customerInfo)
        return isPremium
    }

    @discardableResult
    func restore() async -> Bool {
        guard let info = try? await Purchases.shared.restorePurchases() else { return false }
        ratchet(info)
        return isPremium
    }
}
