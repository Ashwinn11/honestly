import SwiftUI
import WidgetKit

/// Lock Screen widgets are always rendered monochrome/tinted by the system regardless of the
/// colors set here — `SunMark`'s shape (rays + disc outline) still comes through, just not its
/// amber fill, which is expected/standard for this widget family.
struct BigWinsLockScreenWidgetView: View {
    let entry: BigWinsEntry

    var body: some View {
        Group {
            if let line = entry.affirmation {
                Affirmations.text(line)
                    .font(AffirmationWidgetFont.make(name: entry.fontName, size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: entry.textHex))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(1)
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)
            } else {
                Text(loc: "Unlock this widget with Premium")
                    .font(Fonts.ui(10.5, .medium))
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            AffirmationWidgetThemeBackground(themeID: entry.themeID, colorOverrideHex: entry.backgroundHex)
        }
        // Defensive against the same WidgetKit "stuck placeholder" platform bug as the Home
        // Screen widget — see BigWinsWidgetView for details.
        .unredacted()
        .widgetURL(entry.affirmation.flatMap(AppLink.affirmation) ?? AppLink.affirmations)
    }
}

struct BigWinsLockScreenWidget: Widget {
    let kind = "BigWinsLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BigWinsProvider()) { entry in
            BigWinsLockScreenWidgetView(entry: entry)
                // Widgets default to the device's system locale, not the app's in-app language
                // picker — force the same language the app itself is showing.
                .environment(\.locale, Locale(identifier: SharedState.language))
                .environment(\.layoutDirection, Locale.Language(identifier: SharedState.language).characterDirection == .rightToLeft ? .rightToLeft : .leftToRight)
        }
        .configurationDisplayName("Today's affirmation")
        .description("See today's affirmation on your Lock Screen.")
        .supportedFamilies([.accessoryRectangular])
    }
}
