import SwiftUI
import WidgetKit

struct BigWinsWidgetView: View {
    let entry: BigWinsEntry
    @Environment(\.widgetFamily) private var family

    private var quoteSize: CGFloat {
        switch family {
        case .systemSmall: return 15
        case .systemLarge: return 26
        default: return 19
        }
    }

    private var quoteLineLimit: Int {
        switch family {
        case .systemSmall: return 6
        case .systemLarge: return 8
        default: return 4
        }
    }

    private var quoteGlyphSize: CGFloat {
        switch family {
        case .systemSmall: return 14
        case .systemLarge: return 24
        default: return 18
        }
    }

    private var quoteSpacing: CGFloat {
        switch family {
        case .systemSmall: return 4
        case .systemLarge: return 2
        default: return 5
        }
    }

    private var emptySunSize: CGFloat {
        switch family {
        case .systemSmall: return 34
        case .systemLarge: return 60
        default: return 46
        }
    }

    var body: some View {
        Group {
            if let line = entry.affirmation {
                VStack(spacing: quoteSpacing) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: quoteGlyphSize, weight: .semibold))
                        .foregroundStyle(Color(hex: entry.textHex))
                        .accessibilityHidden(true)
                    Affirmations.text(line)
                        .font(AffirmationWidgetFont.make(name: entry.fontName, size: quoteSize, weight: .semibold))
                        .foregroundStyle(Color(hex: entry.textHex))
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
                        .foregroundStyle(Palette.inkSoft)
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

/// Uses the selected editor theme, with the same light surfaces and subdued patterns as the page
/// themes. The affirmation remains the only foreground element in the widget.
struct AffirmationWidgetThemeBackground: View {
    let themeID: String
    var colorOverrideHex: String? = nil

    private var base: Color {
        switch themeID {
        case "grid", "dots": return Color(hex: "F7F6F0")
        case "linen": return Color(hex: "F1ECE1")
        case "ledger": return Color(hex: "F2F4F7")
        case "meadow": return Color(hex: "EEF3E6")
        case "mushroomWood": return Color(hex: "EDE1CD")
        case "library": return Color(hex: "F1E6CE")
        case "inkGold": return Color(hex: "F6F1E3")
        case "midnight": return Color(hex: "E4E7F7")
        case "stargazer": return Color(hex: "E7E9F0")
        case "tide": return Color(hex: "E2EFF3")
        case "seaGlass": return Color(hex: "E7F2EE")
        case "ballet": return Color(hex: "FBEDEE")
        case "cherry": return Color(hex: "FCEAE8")
        case "sunshine": return Color(hex: "FCF3D9")
        case "bubblegum": return Color(hex: "FBEAF4")
        default: return Palette.paper
        }
    }

    var body: some View {
        ZStack {
            baseLayer
            patternLayer
        }
    }

    @ViewBuilder private var baseLayer: some View {
        if let colorOverrideHex {
            Color(hex: colorOverrideHex)
        } else {
            switch themeID {
        case "inkGold":
            LinearGradient(colors: [Color(hex: "F8F2E2"), Color(hex: "EDE7D2")],
                           startPoint: .top, endPoint: .bottom)
        case "midnight":
            LinearGradient(colors: [Color(hex: "E4E7F7"), Color(hex: "EFEAF9")],
                           startPoint: .top, endPoint: .bottom)
        case "tide":
            LinearGradient(colors: [Color(hex: "DDEEF4"), Color(hex: "EAF5EF")],
                           startPoint: .top, endPoint: .bottom)
        default:
            base
            }
        }
    }

    @ViewBuilder private var patternLayer: some View {
        switch themeID {
        case "grid":
            WidgetLinePattern(tint: Palette.ink.opacity(0.06), spacing: 26, vertical: true)
        case "dots":
            WidgetDotPattern(tint: Palette.ink.opacity(0.13), spacing: 22)
        case "linen":
            WidgetLinePattern(tint: Color(hex: "8A7A67").opacity(0.10), spacing: 8)
        case "ledger":
            WidgetLinePattern(tint: Color(hex: "5C6B7A").opacity(0.18), spacing: 26)
        case "meadow":
            WidgetSymbolPattern(symbols: ["leaf.fill", "laurel.leading"], tint: Color(hex: "6E9A5E"),
                                opacity: 0.30, spacing: 82)
        case "mushroomWood":
            WidgetSymbolPattern(symbols: ["leaf.fill", "circle.fill"], tint: Color(hex: "B5654A"),
                                opacity: 0.26, spacing: 78)
        case "library":
            WidgetSymbolPattern(symbols: ["book.closed.fill", "bookmark.fill", "laurel.leading"],
                                tint: Color(hex: "7A3B32"), opacity: 0.22, spacing: 92)
        case "inkGold":
            WidgetSymbolPattern(symbols: ["sparkle", "star.fill"], tint: Color(hex: "B8903F"),
                                opacity: 0.32, spacing: 86)
        case "midnight":
            WidgetSymbolPattern(symbols: ["moon.stars.fill", "star.fill", "sparkle"],
                                tint: Color(hex: "6A6FA8"), opacity: 0.30, spacing: 88)
        case "stargazer":
            WidgetSymbolPattern(symbols: ["star.fill", "sparkle", "star"], tint: Color(hex: "4C5578"),
                                opacity: 0.36, spacing: 62)
        case "tide":
            WidgetWavePattern(tint: Color(hex: "6FA6B8").opacity(0.32))
        case "ballet":
            WidgetSymbolPattern(symbols: ["heart.fill", "sparkle", "circle.fill"],
                                tint: Color(hex: "E9A6B3"), opacity: 0.30, spacing: 78)
        case "cherry":
            WidgetSymbolPattern(symbols: ["heart.fill", "heart"], tint: Color(hex: "C4453F"),
                                opacity: 0.30, spacing: 70)
        case "sunshine":
            WidgetSymbolPattern(symbols: ["cloud.fill", "sun.max.fill", "cloud"],
                                tint: Color(hex: "E3A94A"), opacity: 0.28, spacing: 86)
        case "bubblegum":
            WidgetSymbolPattern(symbols: ["star.fill", "sparkle", "circle.fill"],
                                tint: Color(hex: "C77BB0"), opacity: 0.30, spacing: 74)
        default:
            EmptyView()
        }
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

private struct WidgetLinePattern: View {
    let tint: Color
    let spacing: CGFloat
    var vertical = false

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var y = spacing
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            if vertical {
                var x = spacing
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += spacing
                }
            }
            context.stroke(path, with: .color(tint), lineWidth: 1)
        }
    }
}

private struct WidgetDotPattern: View {
    let tint: Color
    let spacing: CGFloat

    var body: some View {
        Canvas { context, size in
            var path = Path()
            stride(from: spacing, to: size.height, by: spacing).forEach { y in
                stride(from: spacing, to: size.width, by: spacing).forEach { x in
                    path.addEllipse(in: CGRect(x: x - 1.1, y: y - 1.1, width: 2.2, height: 2.2))
                }
            }
            context.fill(path, with: .color(tint))
        }
    }
}

private struct WidgetWavePattern: View {
    let tint: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var y: CGFloat = 28
            while y < size.height {
                var x: CGFloat = 0
                var first = true
                while x <= size.width {
                    let point = CGPoint(x: x, y: y + sin(x / 46 * .pi * 2) * 4)
                    if first { path.move(to: point); first = false }
                    else { path.addLine(to: point) }
                    x += 4
                }
                y += 28
            }
            context.stroke(path, with: .color(tint), lineWidth: 1.2)
        }
    }
}

private struct WidgetSymbolPattern: View {
    let symbols: [String]
    let tint: Color
    let opacity: Double
    let spacing: CGFloat

    var body: some View {
        Canvas { context, size in
            let columns = Int(size.width / spacing) + 2
            let rows = Int(size.height / spacing) + 2
            for row in 0..<rows {
                for column in 0..<columns {
                    let stagger: CGFloat = row.isMultiple(of: 2) ? 0 : spacing / 2
                    let x = CGFloat(column) * spacing + stagger + CGFloat((row * 37 + column * 19) % 23) - 11
                    let y = CGFloat(row) * spacing + CGFloat((row * 13 + column * 31) % 23) - 11
                    let size = CGFloat(13 + (row * 7 + column * 11) % 12)
                    var symbol = context.resolve(Image(systemName: symbols[(row + column) % symbols.count]))
                    symbol.shading = .color(tint)
                    context.drawLayer { layer in
                        layer.opacity = opacity
                        layer.draw(symbol, in: CGRect(x: x - size / 2, y: y - size / 2,
                                                      width: size, height: size))
                    }
                }
            }
        }
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
