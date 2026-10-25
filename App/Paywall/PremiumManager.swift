import Foundation
import Observation
import RevenueCat

/// Cached access keeps purchases usable offline; successful verification updates access.
@MainActor
@Observable
final class PremiumManager {
    private(set) var isPremium = ScreenshotPreview.enabled || SharedState.premiumActive
    private(set) var isLifetime = SharedState.premiumLifetime
    private(set) var offerings: Offerings?
    var errorMessage: String?
    private var configured = false

    func configure() {
        guard !configured, !ScreenshotPreview.enabled else { return }
        configured = true
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: AppConfig.revenueCatAPIKey)
        Task {
            for await info in Purchases.shared.customerInfoStream {
                apply(info)
            }
        }
        Task {
            await refresh()
            await loadOfferings()
        }
    }

    func refresh() async {
        guard configured else { return }
        isPremium = SharedState.premiumActive
        // Keep cached access on network failure; never mistake a failed request for a revocation.
        guard let info = try? await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent) else { return }
        apply(info)
    }

    private func apply(_ info: CustomerInfo) {
        isPremium = info.entitlements[AppConfig.entitlementID]?.isActive == true
        isLifetime = isPremium && info.entitlements[AppConfig.entitlementID]?.expirationDate == nil
        SharedState.premiumExpiration = info.entitlements[AppConfig.entitlementID]?.expirationDate
        SharedState.premiumLifetime = isLifetime
        SharedState.premiumActive = isPremium
    }

    func loadOfferings() async {
        offerings = try? await Purchases.shared.offerings()
    }

    var lifetimePackage: Package? {
        guard let current = offerings?.current else { return nil }
        return current.availablePackages.first {
            $0.identifier == AppConfig.lifetimePackageID && $0.packageType == .lifetime
        } ?? current.lifetime
            ?? current.availablePackages.first { $0.packageType == .lifetime }
    }

    var monthlyPackage: Package? {
        guard let current = offerings?.current else { return nil }
        return current.availablePackages.first {
            $0.identifier == AppConfig.monthlyPackageID && $0.packageType == .monthly
        } ?? current.monthly
            ?? current.availablePackages.first { $0.packageType == .monthly }
    }

    var hasMonthly: Bool { monthlyPackage != nil }
    var monthlyPriceString: String { monthlyPackage?.storeProduct.localizedPriceString ?? "" }

    var hasLifetime: Bool { lifetimePackage != nil }
    var lifetimePriceString: String { lifetimePackage?.storeProduct.localizedPriceString ?? "" }

    @discardableResult
    func purchaseLifetime() async -> Bool {
        await purchaseLifetimeOrMonthly(lifetime: true)
    }

    @discardableResult
    func purchaseMonthly() async -> Bool {
        await purchaseLifetimeOrMonthly(lifetime: false)
    }

    private func purchaseLifetimeOrMonthly(lifetime: Bool) async -> Bool {
        errorMessage = nil
        if (lifetime ? lifetimePackage : monthlyPackage) == nil { await loadOfferings() }
        guard let package = lifetime ? lifetimePackage : monthlyPackage else {
            errorMessage = L10n.localized("This purchase is unavailable. Please try again shortly.")
            return false
        }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            guard !result.userCancelled else { return false }
            apply(result.customerInfo)
            if !isPremium {
                errorMessage = L10n.localized("Your purchase hasn't unlocked Premium yet. Please try Restore purchases.")
            }
            return isPremium
        } catch {
            errorMessage = L10n.localized("Couldn't complete your purchase. Please check your connection and try again.")
            return false
        }
    }

    @discardableResult
    func restore() async -> Bool {
        errorMessage = nil
        do {
            apply(try await Purchases.shared.restorePurchases())
            if !isPremium {
                errorMessage = L10n.localized("No active Premium purchase was found on this Apple ID.")
            }
            return isPremium
        } catch {
            errorMessage = L10n.localized("Couldn't restore purchases. Please check your connection and try again.")
            return false
        }
    }
}
