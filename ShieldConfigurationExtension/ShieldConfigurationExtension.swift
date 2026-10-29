import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The custom shield the user sees on a blocked app. Warm paper, the app's own sun mark, and a
/// name-specific nudge to write today's page.
///
/// Every color here is a flat, static `UIColor(hex:)` (see `Palette`'s "UIKit mirror" section) —
/// deliberately NOT dynamic/trait-adaptive, and `backgroundBlurStyle` is pinned to the explicit
/// `.Light` material variant. That's intentional: the shield must always match the app's paper
/// palette, regardless of the device's system light/dark mode setting.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration(appName: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(appName: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    private func makeConfiguration(appName: String? = nil) -> ShieldConfiguration {
        let appName = appName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = if let appName, !appName.isEmpty {
            L10n.appWaitTitle(for: appName)
        } else {
            L10n.t("shield.title")
        }
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: Palette.paperUI.withAlphaComponent(0.92),
            icon: SunMarkGlyph.image(side: 96, bottomPadding: 24),
            title: .init(text: title, color: Palette.inkUI),
            subtitle: .init(text: "\n" + L10n.t("shield.subtitle"), color: Palette.inkSoftUI),
            primaryButtonLabel: .init(text: L10n.t("shield.primary"), color: .white),
            primaryButtonBackgroundColor: Palette.amberUI)
    }
}

/// A UIKit port of the app's `SunMark` brand glyph (`App/DesignSystem/SunMark.swift`) — same eight
/// ink rays around a gold disc with a black ink outline. The shield extension can't reuse the
/// SwiftUI view directly, so this mirrors its exact geometry; keep the two in sync if `SunMark`
/// ever changes.
enum SunMarkGlyph {
    /// Ray endpoints in `SunMark`'s 100×100 unit viewBox.
    private static let rayLines: [[CGFloat]] = [
        [50, 5, 50, 17], [50, 83, 50, 95], [5, 50, 17, 50], [83, 50, 95, 50],
        [19, 19, 27.5, 27.5], [72.5, 72.5, 81, 81], [81, 19, 72.5, 27.5], [27.5, 72.5, 19, 81],
    ]

    static func image(side: CGFloat, bottomPadding: CGFloat = 0) -> UIImage {
        let size = CGSize(width: side, height: side + bottomPadding)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let s = side / 100
            let lineWidth = 4.5 * s   // matches SunMark's `lineUnits` for sizes ≥ 95

            // Rays.
            c.setStrokeColor(Palette.inkUI.cgColor)
            c.setLineWidth(lineWidth)
            c.setLineCap(.round)
            for l in rayLines {
                c.move(to: CGPoint(x: l[0] * s, y: l[1] * s))
                c.addLine(to: CGPoint(x: l[2] * s, y: l[3] * s))
            }
            c.strokePath()

            // Disc — gold fill, black ink outline.
            let disc = CGRect(x: 30 * s, y: 30 * s, width: 40 * s, height: 40 * s)
            c.setFillColor(Palette.sunDiscUI.cgColor)
            c.fillEllipse(in: disc)
            c.setStrokeColor(Palette.inkUI.cgColor)
            c.setLineWidth(lineWidth)
            c.strokeEllipse(in: disc)
        }
    }
}
