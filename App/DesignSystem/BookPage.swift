import SwiftUI
import UIKit

extension Metrics {
    /// Width of the page edges showing down the screen's right side (see `BookEdges`). It sits
    /// inside the page margin, so the text column is the same with or without it.
    static let bookGutter: CGFloat = 8
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

// MARK: - A page being written

/// The month's book in miniature: its cover swings open and a pencil writes a few lines onto the
/// ruled page — the same book the user writes in every morning, so onboarding shows it before
/// they ever open it. Loops (closing and reopening) or plays once. `onInk` reports how much of
/// the page is written (0…1); `onWritten` fires once the last word is down. Reduce Motion lands
/// on the open, written page straight away.
struct BookWritingScene: View {
    let heading: String?                // String Catalog key, the line at the top of the page
    let lines: [String]                 // String Catalog keys, written one after another
    var pageWidth: CGFloat = 130
    var loops = false
    var onInk: (CGFloat) -> Void = { _ in }
    var onWritten: () -> Void = {}

    @Environment(CoverStore.self) private var covers
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var coverTurned = false   // the front of the cover has swung up to upright
    @State private var insideDown = false    // …and its inside has come down on the left
    @State private var opened = false        // the book has slid over to sit open as a spread
    @State private var rows: [String] = []   // the text, wrapped to the page
    @State private var typed = 0             // characters written so far, across all rows
    @State private var inkOpacity = 1.0

    init(heading: String? = nil, lines: [String], pageWidth: CGFloat = 130, loops: Bool = false,
         onInk: @escaping (CGFloat) -> Void = { _ in }, onWritten: @escaping () -> Void = {}) {
        self.heading = heading
        self.lines = lines
        self.pageWidth = pageWidth
        self.loops = loops
        self.onInk = onInk
        self.onWritten = onWritten
    }

    private var book: MonthBook {
        let c = Calendar.current.dateComponents([.year, .month], from: .now)
        return MonthBook(year: c.year ?? 2026, month: c.month ?? 1, entries: [], isCurrent: true)
    }

    // Page geometry, all relative to the page's width.
    private var w: CGFloat { DesignScale.s(pageWidth) }
    private var h: CGFloat { w * 1.42 }
    private var margin: CGFloat { w * 0.1 }
    private var fontSize: CGFloat { pageWidth * 0.078 }      // Fonts.ui scales this itself
    private var pitch: CGFloat { DesignScale.s(fontSize) * 1.95 }
    private var textTop: CGFloat { h * (heading == nil ? 0.17 : 0.27) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            insideCover
                .rotation3DEffect(.degrees(insideDown ? 0 : 90), axis: (x: 0, y: 1, z: 0),
                                  anchor: .trailing, perspective: 0.5)
            page
                .offset(x: w)
            MonthBookCover(book: book, width: pageWidth)
                .rotation3DEffect(.degrees(coverTurned ? -90 : 0), axis: (x: 0, y: 1, z: 0),
                                  anchor: .leading, perspective: 0.5)
                .offset(x: w)
        }
        .frame(width: w * 2 + Metrics.bookGutter, height: h, alignment: .topLeading)
        // A closed book sits centred; it slides over as it opens into a spread.
        .offset(x: opened ? 0 : -w / 2)
        .accessibilityHidden(true)
        .task { await play() }
    }

    /// The cover's inside, lying open on the left.
    private var insideCover: some View {
        let look = covers.look(for: book)
        let shape = UnevenRoundedRectangle(topLeadingRadius: w * 0.09, bottomLeadingRadius: w * 0.09,
                                           bottomTrailingRadius: w * 0.03, topTrailingRadius: w * 0.03,
                                           style: .continuous)
        return look.frameColor
            .overlay(alignment: .trailing) {
                Rectangle().fill(.black.opacity(0.14)).frame(width: w * 0.07)     // into the spine
            }
            .frame(width: w, height: h)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.ink, lineWidth: 2))
    }

    /// The right-hand page: heading, date, rules, and the words going down with the pencil.
    private var page: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 2,
                                           bottomTrailingRadius: w * 0.04, topTrailingRadius: w * 0.04,
                                           style: .continuous)
        return ZStack(alignment: .topLeading) {
            PageThemeBackground(theme: .paper)
            rules
            VStack(alignment: .leading, spacing: h * 0.02) {
                if let heading {
                    Text(verbatim: L10n.localized(heading))
                        .font(Fonts.display(fontSize * 1.18, .heavy))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2).minimumScaleFactor(0.7)
                }
                Text(verbatim: HDate.monthDay(.now))
                    .font(Fonts.ui(fontSize * 0.86, .heavy))
                    .foregroundStyle(Palette.inkSoft)
            }
            .padding(.horizontal, margin).padding(.top, h * 0.07)
            writing
            pencil
        }
        .frame(width: w, height: h)
        .overlay(alignment: .leading) { BookGutterShade() }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.ink, lineWidth: 2))
        .background(alignment: .trailing) {          // the pages beneath, past the open side
            BookPageStack()
                .frame(width: Metrics.bookGutter, height: h - w * 0.06)
                .offset(x: Metrics.bookGutter - 2)
        }
    }

    private var rules: some View {
        Canvas { ctx, size in
            var y = textTop + pitch * 0.78
            while y < size.height - margin * 0.6 {
                ctx.fill(Path(CGRect(x: margin, y: y, width: size.width - margin * 2, height: 1)),
                         with: .color(Palette.ink.opacity(0.13)))
                y += pitch
            }
        }
    }

    private var writing: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows.indices, id: \.self) { i in
                Text(verbatim: String(rows[i].prefix(max(0, typed - offset(of: i)))))
                    .font(Fonts.ui(fontSize, .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(height: pitch, alignment: .bottomLeading)
            }
        }
        .padding(.leading, margin)
        .padding(.top, textTop - pitch * 0.12)
        .opacity(inkOpacity)
    }

    /// Rests its tip on the end of the word being written.
    private var pencil: some View {
        let (row, x) = penPosition
        return Image(systemName: "pencil")
            .font(.system(size: w * 0.2, weight: .regular))
            .foregroundStyle(Palette.amber)
            .shadow(color: Palette.ink.opacity(0.14), radius: 2, x: 1, y: 3)
            .rotationEffect(.degrees(-12))
            .offset(x: margin + x - w * 0.03, y: textTop + pitch * (CGFloat(row) + 0.75) - w * 0.19)
            .opacity(opened && inkOpacity > 0 ? 1 : 0)
            .animation(.linear(duration: 0.05), value: typed)
    }

    // MARK: Layout of the words

    private var uiFont: UIFont {
        UIFont(name: "Manrope-SemiBold", size: DesignScale.s(fontSize)) ?? .systemFont(ofSize: DesignScale.s(fontSize))
    }

    private func offset(of row: Int) -> Int { rows.prefix(row).reduce(0) { $0 + $1.count } }

    private var penPosition: (Int, CGFloat) {
        guard !rows.isEmpty else { return (0, 0) }
        var row = 0
        while row < rows.count - 1 && typed >= offset(of: row + 1) { row += 1 }
        let done = String(rows[row].prefix(max(0, typed - offset(of: row))))
        return (row, (done as NSString).size(withAttributes: [.font: uiFont]).width)
    }

    /// Greedy word wrap to the page's text width — by character where a language doesn't
    /// separate words with spaces — keeping only the rows the page has room for.
    private func wrap(_ text: String) -> [String] {
        let width = w - margin * 2 - Metrics.bookGutter
        let font = uiFont
        func fits(_ s: String) -> Bool { (s as NSString).size(withAttributes: [.font: font]).width <= width }
        var out: [String] = []
        var line = ""
        for word in text.split(separator: " ").map(String.init) {
            let candidate = line.isEmpty ? word : line + " " + word
            if fits(candidate) { line = candidate; continue }
            if !line.isEmpty { out.append(line + " "); line = "" }
            for ch in word {
                if fits(line + String(ch)) { line.append(ch) } else { out.append(line); line = String(ch) }
            }
        }
        if !line.isEmpty { out.append(line) }
        let room = max(1, Int((h - textTop - margin * 0.6) / pitch))
        return Array(out.prefix(room))
    }

    // MARK: Playing it

    private func play() async {
        rows = wrap(lines.map { L10n.localized($0) }.joined(separator: " "))
        let total = rows.reduce(0) { $0 + $1.count }
        guard !reduceMotion else {
            coverTurned = true
            insideDown = true
            opened = true
            typed = total
            onInk(1)
            onWritten()
            return
        }
        do {
            repeat {
                try await Task.sleep(for: .milliseconds(450))
                withAnimation(.easeInOut(duration: 0.62)) { opened = true }
                withAnimation(.easeIn(duration: 0.3)) { coverTurned = true }
                try await Task.sleep(for: .milliseconds(300))
                withAnimation(.easeOut(duration: 0.32)) { insideDown = true }
                try await Task.sleep(for: .milliseconds(450))
                for c in 1...max(total, 1) {
                    try Task.checkCancellation()
                    typed = c
                    onInk(CGFloat(c) / CGFloat(max(total, 1)))
                    try await Task.sleep(for: .milliseconds(rows.isEmpty ? 0 : 50))
                }
                onWritten()
                guard loops else { return }
                // Let it sit, lift the ink, close the book, and start a fresh page.
                try await Task.sleep(for: .seconds(1.8))
                withAnimation(.easeOut(duration: 0.35)) { inkOpacity = 0 }
                try await Task.sleep(for: .milliseconds(350))
                withAnimation(.easeInOut(duration: 0.62)) { opened = false }
                withAnimation(.easeIn(duration: 0.3)) { insideDown = false }
                try await Task.sleep(for: .milliseconds(300))
                withAnimation(.easeOut(duration: 0.32)) { coverTurned = false }
                try await Task.sleep(for: .milliseconds(450))
                typed = 0
                inkOpacity = 1
                onInk(0)
            } while true
        } catch {
            return
        }
    }
}
