import SwiftUI
import UIKit

extension Metrics {
    /// Width of the page edges showing down the screen's right side (see `BookEdges`). It sits
    /// inside the page margin, so the text column is the same with or without it.
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

/// The book's edges down the whole screen — the spine's shade on the left, the pages beneath on
/// the right — so the entire screen reads as one page, top bar and toolbar included. Sits above
/// everything and takes no touches.
struct BookEdges: View {
    var body: some View {
        HStack(spacing: 0) {
            BookGutterShade()
            Spacer(minLength: 0)
            BookPageStack()
                .frame(width: Metrics.bookGutter)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Palette.ink.opacity(0.12)).frame(width: 1)   // the top page's edge
                }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Closing a page

/// The one control a page carries: a small ink ✕ in its top corner — a mark on the paper, not a
/// button in a bar. Pulling the page down from its top closes it too (`closesOnPullDown`).
struct PageCloseMark: View {
    var action: () -> Void

    init(action: @escaping () -> Void) { self.action = action }

    var body: some View {
        Button { Haptics.tap(); action() } label: {
            Image(systemName: "xmark")
                .font(.system(size: DesignScale.s(14), weight: .bold))
                .foregroundStyle(Palette.ink.opacity(0.7))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.88))
        .accessibilityLabel(Text("Close"))
    }
}

extension View {
    /// Close the page by pulling it down from its top edge — like setting the book down. Only a
    /// pull that starts near the top counts, so scrolling back up through a long page never
    /// closes it.
    func closesOnPullDown(topBand: CGFloat = 140, _ action: @escaping () -> Void) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                guard value.startLocation.y < topBand,
                      value.translation.height > 110,
                      abs(value.translation.width) < 90 else { return }
                action()
            }
        )
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
