import SwiftUI
import UIKit

extension Metrics {
    /// How far a book page sits in from the screen edge while writing, so the book's cover shows
    /// around it. Writing pads its text by `pageHorizontalInset - bookGutter`, which keeps the
    /// text column exactly as wide as the reader's (attachments are laid out to that width).
    static let bookGutter: CGFloat = 8
}

// MARK: - Ruled lines

extension UITextView {
    /// Draws a notebook rule under every line of text — following the real line layout, so the
    /// words sit on the rules whatever their size — then keeps ruling down the rest of the view at
    /// the body text's pitch. Lines holding a photo, doodle or sticker get no rule through them.
    /// Call from `draw(_:)`; the text itself draws above this.
    func drawJournalRules(in rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let font = RichTextEditor.defaultFont
        let pitch = font.lineHeight + RichTextEditor.defaultParagraphStyle.lineSpacing
        let drop = abs(font.descender) * 0.45          // rules sit just under the baseline
        let top = textContainerInset.top
        var baselines: [CGFloat] = []

        if let layout = textLayoutManager, let doc = layout.textContentManager?.documentRange {
            _ = layout.enumerateTextLayoutFragments(from: doc.location, options: [.ensuresLayout]) { fragment in
                let frame = fragment.layoutFragmentFrame
                for line in fragment.textLineFragments {
                    let bounds = line.typographicBounds
                    guard bounds.height < pitch * 1.8 else { continue }
                    baselines.append(top + frame.minY + bounds.minY + line.glyphOrigin.y)
                }
                return true
            }
        }
        if baselines.isEmpty { baselines.append(top + font.ascender) }

        var y = baselines.last! + pitch
        while y < bounds.height - textContainerInset.bottom + pitch * 0.5 {
            baselines.append(y)
            y += pitch
        }

        let left = textContainerInset.left
        let right = bounds.width - textContainerInset.right
        ctx.setStrokeColor(UIColor(Palette.ink).withAlphaComponent(0.11).cgColor)
        ctx.setLineWidth(1)
        for b in baselines {
            let ry = (b + drop).rounded() + 0.5
            guard ry >= rect.minY - 1, ry <= rect.maxY + 1 else { continue }
            ctx.move(to: CGPoint(x: left, y: ry))
            ctx.addLine(to: CGPoint(x: right, y: ry))
        }
        ctx.strokePath()
    }
}

/// The read-only page's text view, ruled like the writing page.
final class RuledTextView: UITextView {
    var ruled = false {
        didSet { if ruled != oldValue { contentMode = ruled ? .redraw : .scaleToFill; setNeedsDisplay() } }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if ruled { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        if ruled { drawJournalRules(in: rect) }
    }
}

// MARK: - Page furniture

/// The shadow where a page curves into the book's spine.
struct BookGutterShade: View {
    var body: some View {
        LinearGradient(colors: [Palette.ink.opacity(0.13), Palette.ink.opacity(0.03), .clear],
                       startPoint: .leading, endPoint: .trailing)
            .frame(width: 18)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Edges of the pages under the one being written, peeking out on the open side.
struct BookPageStack: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Palette.cream))
            var x: CGFloat = 1.5
            while x < size.width {
                ctx.fill(Path(CGRect(x: x, y: 0, width: 0.7, height: size.height)),
                         with: .color(Color(hex: "D8CBB6")))
                x += 2.2
            }
        }
        .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 10, topTrailingRadius: 10, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Opening the book

/// Plays over the writing page as it appears: the month's cover swings open, then the pages
/// already written riffle past to the fresh one. Pure decoration — it ends by removing itself.
struct BookOpeningOverlay: View {
    let look: CoverLook
    var month: Date = Date()
    let pagesBefore: Int
    var onFinished: () -> Void

    @State private var coverOpen = false
    @State private var riffled = false

    init(look: CoverLook, month: Date = Date(), pagesBefore: Int, onFinished: @escaping () -> Void) {
        self.look = look
        self.month = month
        self.pagesBefore = pagesBefore
        self.onFinished = onFinished
    }

    private var sheets: Int { min(pagesBefore, 14) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                ForEach(0..<sheets, id: \.self) { i in
                    // Top sheet (highest index) turns first.
                    let order = sheets - 1 - i
                    sheet
                        .rotation3DEffect(.degrees(riffled ? -95 : 0), axis: (x: 0, y: 1, z: 0),
                                          anchor: .leading, perspective: 0.45)
                        .opacity(riffled ? 0 : 1)
                        .animation(.easeIn(duration: 0.22).delay(0.05 * Double(order)), value: riffled)
                }
                cover(size: geo.size)
                    .rotation3DEffect(.degrees(coverOpen ? -95 : 0), axis: (x: 0, y: 1, z: 0),
                                      anchor: .leading, perspective: 0.45)
                    .opacity(coverOpen ? 0 : 1)
                    .animation(.easeIn(duration: 0.42), value: coverOpen)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            try? await Task.sleep(for: .seconds(0.25))
            coverOpen = true
            Haptics.tap()
            try? await Task.sleep(for: .seconds(0.3))
            riffled = true
            let ticks = min(sheets, 8)
            for _ in 0..<ticks {
                Haptics.select()
                try? await Task.sleep(for: .seconds(0.06))
            }
            // Let the last sheet finish turning: the riffle lasts 0.05 s per sheet plus one turn.
            let riffle = 0.05 * Double(max(sheets - 1, 0)) + 0.22
            try? await Task.sleep(for: .seconds(max(0.12, riffle - 0.06 * Double(ticks) + 0.12)))
            onFinished()
        }
    }

    private var sheet: some View {
        PageThemeBackground(theme: .paper)
            .overlay(alignment: .leading) { BookGutterShade() }
            .overlay(Rectangle().strokeBorder(Palette.ink.opacity(0.12), lineWidth: 1))
    }

    private func cover(size: CGSize) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let photo = look.photo {
                Image(uiImage: photo).resizable().scaledToFill()
                    .frame(width: size.width, height: size.height).clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .center, endPoint: .bottom)
            } else {
                look.color
            }
            Rectangle().fill(.black.opacity(0.16)).frame(width: 18).frame(maxHeight: .infinity)
            Text(verbatim: HDate.monthName(month))
                .font(Fonts.display(44, .heavy)).foregroundStyle(look.ink)
                .padding(.leading, 36).padding(.bottom, 60)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

// MARK: - Closing the book

/// The finished page goes into the book: an open page with the cover swinging shut over it,
/// then the closed book settles with its ribbon.
struct ClosingBookView: View {
    let book: MonthBook
    var width: CGFloat = 150

    @State private var closed = false

    init(book: MonthBook, width: CGFloat = 150) {
        self.book = book
        self.width = width
    }

    var body: some View {
        let w = DesignScale.s(width)
        ZStack(alignment: .topLeading) {
            // The page just written, lying open until the cover comes down over it.
            PageThemeBackground(theme: .paper)
                .frame(width: w, height: w * 1.42)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 3,
                                                  bottomTrailingRadius: 10, topTrailingRadius: 10, style: .continuous))
                .overlay(alignment: .leading) { BookGutterShade() }
                .opacity(closed ? 0 : 1)

            MonthBookCover(book: book, width: width)
                .rotation3DEffect(.degrees(closed ? 0 : -150), axis: (x: 0, y: 1, z: 0),
                                  anchor: .leading, perspective: 0.5)
                .opacity(closed ? 1 : 0)
        }
        .frame(width: w * 1.15, height: w * 1.42, alignment: .topLeading)
        .rotationEffect(.degrees(closed ? -3 : 0))
        .task {
            try? await Task.sleep(for: .seconds(0.35))
            withAnimation(.spring(response: 0.7, dampingFraction: 0.78)) { closed = true }
            try? await Task.sleep(for: .seconds(0.45))
            Haptics.success()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: HDate.monthTitle(book.firstOfMonth)))
    }
}
