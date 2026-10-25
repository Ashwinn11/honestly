import SwiftUI
import WidgetKit

/// Lock Screen widgets are always rendered monochrome/tinted by the system regardless of the
/// colors set here — `SunMark`'s shape (rays + disc outline) still comes through, just not its
/// amber fill, which is expected/standard for this widget family.
struct BigWinsLockScreenWidgetView: View {
    let entry: BigWinsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(loc: "Today's affirmation")
                    .font(Fonts.ui(10, .heavy))
                    .textCase(.uppercase)
                SunMark(size: 12, muted: entry.affirmation == nil)
            }
            if let line = entry.affirmation {
                Affirmations.text(line)
                    .font(Fonts.ui(12.5, .semibold))
                    .lineLimit(2)
            } else {
                Text(loc: "Unlock this widget with Premium")
                    .font(Fonts.ui(10.5, .medium))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
        // Defensive against the same WidgetKit "stuck placeholder" platform bug as the Home
        // Screen widget — see BigWinsWidgetView for details.
        .unredacted()
        .widgetURL(AppLink.affirmations)
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
