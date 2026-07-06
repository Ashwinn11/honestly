import SwiftUI
import WidgetKit

struct BigWinsWidgetView: View {
    let entry: BigWinsEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SunMark(size: 36, muted: entry.affirmation == nil)
            VStack(alignment: .leading, spacing: 6) {
                Text(loc: "Today's affirmation")
                    .font(Fonts.ui(11.5, .heavy))
                    .tracking(0.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.inkSofter)
                if let text = entry.affirmation {
                    // The user's own words — never localized/rewritten (matches AffirmationNudge).
                    Text(text)
                        .font(Fonts.display(19, .semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(loc: "Your affirmations will land here\nonce you've written this morning.")
                        .font(Fonts.ui(14, .semibold))
                        .foregroundStyle(Palette.inkSofter)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { Palette.paper }
        // Defensive: a well-documented WidgetKit platform bug (FB8210627, reported since iOS 14,
        // still occurring on iOS 17.3, physical devices only) can leave a widget stuck showing its
        // placeholder — which the system auto-redacts — even once real timeline data is available.
        // `.unredacted()` guarantees actual content is still legible if that happens.
        .unredacted()
    }
}

struct BigWinsWidget: Widget {
    // Renamed from "BigWinsWidget" — the old identifier accumulated stuck placeholder state across
    // many rebuild/reinstall cycles during development (a widget's timeline cache is tracked by
    // `kind`, somewhat independently of the app install itself). A fresh identifier guarantees iOS
    // has no prior state to inherit.
    let kind = "BigWinsAffirmationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BigWinsProvider()) { entry in
            BigWinsWidgetView(entry: entry)
                // Widgets run in their own process and default to the device's system locale —
                // they don't inherit the app's custom in-app language picker. Force the same
                // language the app itself is showing.
                .environment(\.locale, Locale(identifier: SharedState.language))
        }
        .configurationDisplayName("Today's affirmation")
        .description("See today's affirmation right on your Home Screen.")
        .supportedFamilies([.systemMedium])
    }
}
