import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The custom shield the user sees on a blocked app. Warm paper, a soft sunrise
/// glyph, gentle copy, and an amber "do your ritual" button — a nudge, not a wall.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    private func makeConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: Palette.paperUI.withAlphaComponent(0.92),
            icon: SunriseGlyph.image(side: 96),
            title: .init(text: L10n.t("shield.title"), color: Palette.inkUI),
            subtitle: .init(text: L10n.t("shield.subtitle"), color: Palette.inkSoftUI),
            primaryButtonLabel: .init(text: L10n.t("shield.primary"), color: .white),
            primaryButtonBackgroundColor: Palette.amberUI,
            secondaryButtonLabel: .init(text: L10n.t("shield.secondary"), color: Palette.inkSoftUI))
    }
}

/// A rendered sunrise mark so the shield feels bespoke instead of a system glyph.
enum SunriseGlyph {
    static func image(side: CGFloat) -> UIImage {
        let size = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let center = CGPoint(x: side / 2, y: side * 0.62)
            let sunR = side * 0.26
            let amber = Palette.amberUI

            // Rays.
            c.setStrokeColor(amber.withAlphaComponent(0.9).cgColor)
            c.setLineWidth(side * 0.035)
            c.setLineCap(.round)
            let rayCount = 9
            for i in 0..<rayCount {
                let a = (.pi) * (Double(i) / Double(rayCount - 1))   // upper semicircle
                let inner = sunR + side * 0.08
                let outer = sunR + side * 0.20
                let sx = center.x - CGFloat(cos(a)) * inner
                let sy = center.y - CGFloat(sin(a)) * inner
                let ex = center.x - CGFloat(cos(a)) * outer
                let ey = center.y - CGFloat(sin(a)) * outer
                c.move(to: CGPoint(x: sx, y: sy))
                c.addLine(to: CGPoint(x: ex, y: ey))
            }
            c.strokePath()

            // Sun disc with a soft gradient.
            let disc = CGRect(x: center.x - sunR, y: center.y - sunR, width: sunR * 2, height: sunR * 2)
            c.saveGState()
            c.addEllipse(in: disc)
            c.clip()
            let colors = [amber.withAlphaComponent(1).cgColor,
                          amber.withAlphaComponent(0.75).cgColor] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors, locations: [0, 1]) {
                c.drawLinearGradient(grad,
                                     start: CGPoint(x: center.x, y: center.y - sunR),
                                     end: CGPoint(x: center.x, y: center.y + sunR),
                                     options: [])
            }
            c.restoreGState()

            // Horizon line.
            c.setStrokeColor(Palette.inkSoftUI.withAlphaComponent(0.5).cgColor)
            c.setLineWidth(side * 0.03)
            c.move(to: CGPoint(x: side * 0.16, y: center.y + sunR * 0.7))
            c.addLine(to: CGPoint(x: side * 0.84, y: center.y + sunR * 0.7))
            c.strokePath()
        }
    }
}
