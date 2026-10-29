import SwiftUI
import WidgetKit

struct BigWinsWidgetView: View {
    let entry: BigWinsEntry
    @Environment(\.widgetFamily) private var family

    /// On a dark theme the default ink turns light; a picked colour, or a custom background, keeps
    /// the text exactly as chosen.
    private var textColor: Color {
        let theme = PageTheme.from(entry.themeID)
        return Color(hex: entry.backgroundHex == nil ? theme.widgetTextHex(chosen: entry.textHex) : entry.textHex)
    }

    /// iOS 27's tall extra-large size (the iPhone's fourth size) uses the iPad extra-large sizing.
    private var sizeFamily: WidgetFamily {
        if #available(iOS 27.0, *), family == .systemExtraLargePortrait { return .systemExtraLarge }
        return family
    }

    private var quoteSize: CGFloat {
        switch sizeFamily {
        case .systemSmall: return 15
        case .systemLarge: return 26
        case .systemExtraLarge: return 34
        default: return 19
        }
    }

    private var quoteLineLimit: Int {
        switch sizeFamily {
        case .systemSmall: return 6
        case .systemLarge: return 8
        case .systemExtraLarge: return 8
        default: return 4
        }
    }

    private var quoteGlyphSize: CGFloat {
        switch sizeFamily {
        case .systemSmall: return 14
        case .systemLarge: return 24
        case .systemExtraLarge: return 30
        default: return 18
        }
    }

    private var quoteSpacing: CGFloat {
        switch sizeFamily {
        case .systemSmall: return 4
        case .systemLarge: return 2
        case .systemExtraLarge: return 6
        default: return 5
        }
    }

    private var emptySunSize: CGFloat {
        switch sizeFamily {
        case .systemSmall: return 34
        case .systemLarge: return 60
        case .systemExtraLarge: return 72
        default: return 46
        }
    }

    var body: some View {
        Group {
            if let line = entry.affirmation {
                VStack(spacing: quoteSpacing) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: quoteGlyphSize, weight: .semibold))
                        .foregroundStyle(textColor)
                        .accessibilityHidden(true)
                    Affirmations.text(line)
                        .font(AffirmationWidgetFont.make(name: entry.fontName, size: quoteSize, weight: .semibold))
                        .foregroundStyle(textColor)
                        .multilineTextAlignment(.center)
                        .lineSpacing(family == .systemSmall ? 1 : 3)
                        .lineLimit(quoteLineLimit)
                        .minimumScaleFactor(0.68)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(family == .systemSmall ? 10 : 18)
            } else {
                VStack(spacing: family == .systemSmall ? 8 : 12) {
                    SunMark(size: emptySunSize)
                        .accessibilityHidden(true)
                    Text(loc: entry.needsSetup ? "Open Honestly to get started" : "Unlock this widget with Premium")
                        .font(Fonts.ui(family == .systemSmall ? 13 : 16, .semibold))
                        .foregroundStyle(entry.backgroundHex == nil ? PageTheme.from(entry.themeID).inkSoft : Palette.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(16)
            }
        }
        .containerBackground(for: .widget) {
            AffirmationWidgetThemeBackground(themeID: entry.themeID, colorOverrideHex: entry.backgroundHex)
        }
        .unredacted()
        .widgetURL(entry.affirmation.flatMap(AppLink.affirmation) ?? AppLink.affirmations)
    }
}

/// The widget's page: the same theme drawing as the journal (`PageThemeSurface`), with the user's
/// own background colour in place of the theme's when one is picked.
struct AffirmationWidgetThemeBackground: View {
    let themeID: String
    var colorOverrideHex: String? = nil

    var body: some View {
        PageThemeSurface(theme: PageTheme.from(themeID),
                         backdropOverride: colorOverrideHex.map { Color(hex: $0) })
    }
}

enum AffirmationWidgetFont {
    private static let postScriptNames: [String: String] = [
        "Manrope": "Manrope-SemiBold",
        "Georgia": "Georgia",
        "Baskerville": "Baskerville",
        "Didot": "Didot",
        "Typewriter": "AmericanTypewriter",
        "Futura": "Futura-Medium",
        "Gill Sans": "GillSans",
        "Palatino": "Palatino-Roman",
        "Noteworthy": "Noteworthy-Light",
        "Bradley Hand": "BradleyHandITCTT-Bold",
        "Marker Felt": "MarkerFelt-Thin",
        "Chalkboard": "ChalkboardSE-Regular",
        "Snell Roundhand": "SnellRoundhand-Bold",
    ]

    static func make(name: String, size: CGFloat, weight: Font.Weight) -> Font {
        if name == "New York" { return .system(size: size, weight: weight, design: .serif) }
        return .custom(postScriptNames[name] ?? postScriptNames["Manrope"]!, size: size).weight(weight)
    }
}

struct BigWinsWidget: Widget {
    let kind = "BigWinsAffirmationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BigWinsProvider()) { entry in
            BigWinsWidgetView(entry: entry)
                .environment(\.locale, Locale(identifier: SharedState.language))
                .environment(\.layoutDirection, Locale.Language(identifier: SharedState.language).characterDirection == .rightToLeft ? .rightToLeft : .leftToRight)
        }
        .configurationDisplayName("Today's affirmation")
        .description("See today's affirmation right on your Home Screen.")
        .supportedFamilies(Self.families)
    }

    /// iOS 27 adds a tall extra-large size on iPhone; left out, it shows there as unavailable.
    private static var families: [WidgetFamily] {
        var families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]
        if #available(iOS 27.0, *) { families.append(.systemExtraLargePortrait) }
        return families
    }
}
