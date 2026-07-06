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
                SunMark(size: 12, muted: entry.affirmation == nil)
                Text(loc: "Today's affirmation")
                    .font(Fonts.ui(10, .heavy))
                    .textCase(.uppercase)
            }
            if let text = entry.affirmation {
                // The user's own words — never localized/rewritten (matches AffirmationNudge).
                Text(text)
                    .font(Fonts.ui(12.5, .semibold))
                    .lineLimit(2)
            } else {
                Text(loc: "Your affirmations will land here\nonce you've written this morning.")
                    .font(Fonts.ui(10.5, .medium))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
        // Defensive against the same WidgetKit "stuck placeholder" platform bug as the Home
        // Screen widget — see BigWinsWidgetView for details.
        .unredacted()
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
        }
        .configurationDisplayName("Today's affirmation")
        .description("See today's affirmation on your Lock Screen.")
        .supportedFamilies([.accessoryRectangular])
    }
}
