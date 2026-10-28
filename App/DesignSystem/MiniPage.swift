import SwiftUI

/// A page shown small — the real page in miniature: the same header (the day over its month and
/// year, the mood) and its words with their photos, doodles and stickers, laid out as on a phone and shrunk to the card. The one card for a page anywhere pages
/// are listed: a book's grid, the Library's search results, the book closing on a finished page.
/// With a search term it shows the words from near the first match instead, the match highlighted.
struct MiniPage: View {
    let entry: JournalEntry
    var highlight: String? = nil
    @State private var rich: NSAttributedString?

    init(entry: JournalEntry, highlight: String? = nil) {
        self.entry = entry
        self.highlight = highlight
        _rich = State(initialValue: Self.decoded.object(forKey: Self.key(for: entry)))
    }

    /// Decoding a page's formatting reads its photos back from disk, so each page is decoded once.
    private static let decoded = NSCache<NSString, NSAttributedString>()
    private static func key(for entry: JournalEntry) -> NSString {
        "\(entry.id.uuidString)-\(entry.richContent?.count ?? 0)-\(entry.wordCount)" as NSString
    }

    /// The width the page is laid out at before it's shrunk: the reading page's own width, so
    /// photos and doodles sit exactly as they were placed instead of being refitted.
    private var pageWidth: CGFloat { min(UIScreen.main.bounds.width, Metrics.maxContentWidth) }

    private var searching: Bool {
        !(highlight?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
    }

    var body: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 3,
                                           bottomTrailingRadius: 9, topTrailingRadius: 9, style: .continuous)
        Color.clear
            .aspectRatio(3 / 4.4, contentMode: .fit)
            .overlay(alignment: .topLeading) {
                GeometryReader { geo in
                    // Laid out at a whole page's size, not the card's — given only the card's
                    // small height, the words were squeezed onto one truncated line.
                    page
                        .frame(width: pageWidth, height: pageWidth * 4.4 / 3, alignment: .topLeading)
                        .scaleEffect(geo.size.width / pageWidth, anchor: .topLeading)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                }
            }
            .background(PageThemeBackground(theme: PageTheme.from(entry.themeID)))
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.ink, lineWidth: 1.5))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: HDate.dayMonthYear(entry.date) + ". " + String(entry.journal.prefix(140))))
            .task(id: Self.key(for: entry)) { await decode() }
    }

    private var page: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Just the header and the words — at card size the faint prompt only crowds them out.
            PageHeader(date: entry.date, mood: entry.moodRaw) { EmptyView() }
            words.padding(.top, 14)
        }
        .padding(EdgeInsets(top: 16, leading: Metrics.pageHorizontalInset,
                            bottom: 0, trailing: Metrics.pageHorizontalInset))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var words: some View {
        if !searching, let rich, rich.length > 0 {
            RichContentView(attributedText: rich)
        } else {
            Text(lines)
                .font(Fonts.ui(16, .medium)).foregroundStyle(Palette.inkBody)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func decode() async {
        guard let data = entry.richContent, !data.isEmpty else { rich = nil; return }
        let key = Self.key(for: entry)
        if let cached = Self.decoded.object(forKey: key) { rich = cached; return }
        let result = await Task.detached(priority: .userInitiated) { NSAttributedString.from(rtfdData: data) }.value
        if let result { Self.decoded.setObject(result, forKey: key) }
        rich = result
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
