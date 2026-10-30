import SwiftUI
import WidgetKit

/// Lock Screen widgets use a fixed white foreground for legibility. Home Screen widget colors
/// remain customizable independently.
struct BigWinsLockScreenWidgetView: View {
    let entry: BigWinsEntry

    var body: some View {
        Group {
            if let line = entry.affirmation {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    QuoteMark(size: 9, weight: .regular)
                    Affirmations.text(line)
                        .font(AffirmationWidgetFont.make(name: entry.fontName, size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(1)
                        .lineLimit(3)
                        .minimumScaleFactor(0.78)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                // The same quote mark as an affirmation: size, weight and place on the first line.
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    QuoteMark(size: 9, weight: .regular)
                    Text(loc: entry.needsSetup ? "Open Honestly to get started" : "Unlock this widget with Premium")
                        .font(Fonts.ui(10.5, .medium))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                }
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
        .description("Keep today's affirmation in view with a small widget.")
        .supportedFamilies([.accessoryRectangular])
    }
}
