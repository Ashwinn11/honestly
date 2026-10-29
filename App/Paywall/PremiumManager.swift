import Foundation
import Observation
import RevenueCat

/// Cached access keeps purchases usable offline; successful verification updates access.
@MainActor
@Observable
final class PremiumManager {
    private(set) var isPremium = SharedState.premiumActive
    private(set) var isLifetime = SharedState.premiumLifetime
    private(set) var offerings: Offerings?
    var errorMessage: String?
    private var configured = false

    init() {
        // Installs that were already Premium before claiming existed keep it without a restore.
        if SharedState.premiumActive && !SharedState.premiumClaimed { SharedState.premiumClaimed = true }
    }

    func configure() {
        guard !configured else { return }
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
        // Only a purchase or restore made on this install unlocks Premium — an entitlement that
        // RevenueCat merely finds on the Apple ID waits for Restore purchases (see `premiumClaimed`).
        isPremium = SharedState.premiumClaimed && info.entitlements[AppConfig.entitlementID]?.isActive == true
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

    var annualPackage: Package? {
        guard let current = offerings?.current else { return nil }
        return current.availablePackages.first {
            $0.identifier == AppConfig.annualPackageID && $0.packageType == .annual
        } ?? current.annual
            ?? current.availablePackages.first { $0.packageType == .annual }
    }

    var hasMonthly: Bool { monthlyPackage != nil }
    var monthlyPriceString: String { monthlyPackage?.storeProduct.localizedPriceString ?? "" }

    var hasAnnual: Bool { annualPackage != nil }
    var annualPriceString: String { annualPackage?.storeProduct.localizedPriceString ?? "" }
    /// The yearly price spread over twelve months — "$2.49".
    var annualPerMonthString: String { annualPackage?.storeProduct.localizedPricePerMonth ?? "" }

    /// Twelve months at the monthly price, in the monthly product's currency — the anchor the
    /// yearly price is struck against.
    var monthlyForAYearString: String {
        guard let product = monthlyPackage?.storeProduct,
              let formatter = product.priceFormatter else { return "" }
        return formatter.string(from: (product.price * 12) as NSDecimalNumber) ?? ""
    }

    /// How much less the yearly plan costs than twelve monthly payments, rounded down; nil when
    /// either price is missing or yearly isn't cheaper.
    var annualSavingsPercent: Int? {
        guard let annual = annualPackage?.storeProduct.price,
              let monthly = monthlyPackage?.storeProduct.price, monthly > 0 else { return nil }
        let ratio = NSDecimalNumber(decimal: annual / (monthly * 12)).doubleValue
        let percent = Int((1 - ratio) * 100)
        return percent > 0 ? percent : nil
    }

    var hasLifetime: Bool { lifetimePackage != nil }
    var lifetimePriceString: String { lifetimePackage?.storeProduct.localizedPriceString ?? "" }

    @discardableResult
    func purchaseLifetime() async -> Bool {
        await purchase(\.lifetimePackage)
    }

    @discardableResult
    func purchaseMonthly() async -> Bool {
        await purchase(\.monthlyPackage)
    }

    @discardableResult
    func purchaseAnnual() async -> Bool {
        await purchase(\.annualPackage)
    }

    private func purchase(_ plan: KeyPath<PremiumManager, Package?>) async -> Bool {
        errorMessage = nil
        if self[keyPath: plan] == nil { await loadOfferings() }
        guard let package = self[keyPath: plan] else {
            errorMessage = L10n.localized("This purchase is unavailable. Please try again shortly.")
            return false
        }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            guard !result.userCancelled else { return false }
            SharedState.premiumClaimed = true
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
            let info = try await Purchases.shared.restorePurchases()
            if info.entitlements[AppConfig.entitlementID]?.isActive == true { SharedState.premiumClaimed = true }
            apply(info)
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

// MARK: - What Premium unlocks

/// Every Premium feature — the one place the free/Premium line is drawn. Screens ask
/// `premium.allows(_:)` (or gate an action with `flow.requiring(_:premium:_:)`) instead of
/// checking `isPremium` themselves, so moving a feature across the line is a one-line change here.
enum PremiumFeature {
    case appBlocking          // Screen Time: apps stay asleep until the page is written
    case fullHistory          // months before this one: reading, search, covers
    case editPages            // editing a page after it's written
    case iCloudBackup
    case ownPrompts           // writing your own prompts (picking from the list is free)
    case ownAffirmations      // writing your own affirmations
    case fullAffirmations     // the whole affirmation library, not the free rotation
    case widget
    case pageThemes           // switching to a theme you're not already on
    case allStickers          // sticker packs beyond the first
    case morePhotos           // more photos/doodles on a page than the free allowance

    /// Photos and doodles a page can hold without Premium.
    static let freePhotosPerPage = 1
    /// Sticker packs open without Premium (the first ones in the picker).
    static let freeStickerPacks = 1
}

extension PremiumManager {
    func allows(_ feature: PremiumFeature) -> Bool {
        switch feature {
        case .appBlocking, .fullHistory, .editPages, .iCloudBackup, .ownPrompts, .ownAffirmations,
             .fullAffirmations, .widget, .pageThemes, .allStickers, .morePhotos:
            return isPremium
        }
    }
}

extension AppFlow {
    /// Runs `action` when `feature` is unlocked; otherwise opens the paywall.
    func requiring(_ feature: PremiumFeature, premium: PremiumManager, _ action: () -> Void) {
        if premium.allows(feature) { action() } else { showPaywall() }
    }
}
