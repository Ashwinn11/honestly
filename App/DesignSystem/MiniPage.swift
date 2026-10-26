import SwiftUI

/// A page shown small — its own theme paper, date, mood and opening lines. The one card for a
/// page anywhere pages are listed: a book's "all pages" grid and the Library's search results.
/// With a search term, the lines shown start near the first match and the match is highlighted.
struct MiniPage: View {
    let entry: JournalEntry
    var highlight: String? = nil

    init(entry: JournalEntry, highlight: String? = nil) {
        self.entry = entry
        self.highlight = highlight
    }

    var body: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 3,
                                           bottomTrailingRadius: 9, topTrailingRadius: 9, style: .continuous)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(verbatim: HDate.monthDay(entry.date))
                    .font(Fonts.ui(11, .heavy)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                MoodFace(mood: entry.moodRaw, size: 14)
            }
            Text(lines)
                .font(Fonts.ui(9.5, .semibold)).foregroundStyle(Palette.inkBody)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(9)
        .aspectRatio(3 / 4.4, contentMode: .fit)
        .background(PageThemeBackground(theme: PageTheme.from(entry.themeID)))
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.ink, lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }

    /// The page's text — from a little before the first match when searching, so the match shows.
    private var lines: AttributedString {
        let text = entry.journal
        guard let term = highlight?.trimmingCharacters(in: .whitespaces), !term.isEmpty,
              let hit = text.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return AttributedString(text)
        }
        let lead = text.distance(from: text.startIndex, to: hit.lowerBound)
        let start = lead > 40 ? text.index(hit.lowerBound, offsetBy: -30) : text.startIndex
        var excerpt = AttributedString((start == text.startIndex ? "" : "…") + text[start...])
        if let mark = excerpt.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) {
            excerpt[mark].backgroundColor = Palette.sunDisc.opacity(0.45)
            excerpt[mark].foregroundColor = Palette.ink
        }
        return excerpt
    }
}
