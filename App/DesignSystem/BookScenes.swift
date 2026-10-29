import SwiftUI
import UIKit

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
            // The page just written — its date, mood and first lines — lying open until the cover
            // comes down over it.
            Group {
                if let page = book.entries.last {
                    MiniPage(entry: page)
                } else {
                    PageThemeBackground(theme: .paper)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 3,
                                                          bottomTrailingRadius: 10, topTrailingRadius: 10, style: .continuous))
                }
            }
                .frame(width: w, height: w * 1.42)
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
            try? await Task.sleep(for: .seconds(1.1))          // long enough to see your words on it
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
    var mood = 0                        // the face in the page's header
    let lines: [String]                 // String Catalog keys, written one after another
    var pageWidth: CGFloat = 130
    var loops = false
    var onInk: (CGFloat) -> Void = { _ in }
    var onWritten: () -> Void = {}

    @Environment(CoverStore.self) private var covers
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingAnimationsActive) private var animationsActive
    @State private var coverTurned = false   // the front of the cover has swung up to upright
    @State private var insideDown = false    // …and its inside has come down on the left
    @State private var opened = false        // the book has slid over to sit open as a spread
    @State private var rows: [String] = []   // the text, wrapped to the page
    @State private var typed = 0             // characters written so far, across all rows
    @State private var inkOpacity = 1.0

    init(mood: Int = 0, lines: [String], pageWidth: CGFloat = 130, loops: Bool = false,
         onInk: @escaping (CGFloat) -> Void = { _ in }, onWritten: @escaping () -> Void = {}) {
        self.mood = mood
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
    // The real page header, laid out at the real page's width and shrunk onto this page.
    private var headerTop: CGFloat { h * 0.06 }
    private var realColumn: CGFloat {
        min(UIScreen.main.bounds.width, Metrics.maxContentWidth) - Metrics.pageHorizontalInset * 2
    }
    private var headerScale: CGFloat { (w - margin * 2) / realColumn }
    private var headerHeight: CGFloat { DesignScale.s(98) * headerScale }   // the big day + its month line
    private var textTop: CGFloat { headerTop + headerHeight + h * 0.04 }

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
        .task(id: animationsActive) {
            reset()
            guard animationsActive else { return }
            await play()
        }
    }

    private func reset() {
        coverTurned = false
        insideDown = false
        opened = false
        rows = []
        typed = 0
        inkOpacity = 1
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

    /// The right-hand page: the same header as a real page, rules, and the words going down with
    /// the pencil.
    private var page: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 2,
                                           bottomTrailingRadius: w * 0.04, topTrailingRadius: w * 0.04,
                                           style: .continuous)
        return ZStack(alignment: .topLeading) {
            PageThemeBackground(theme: .paper)
            rules
            PageHeader(date: .now, mood: mood) { EmptyView() }
                .frame(width: realColumn, alignment: .leading)
                .scaleEffect(headerScale, anchor: .topLeading)
                .frame(width: w - margin * 2, height: headerHeight, alignment: .topLeading)
                .padding(.leading, margin).padding(.top, headerTop)
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
                try await Task.sleep(for: .milliseconds(220))
                withAnimation(.easeInOut(duration: 0.46)) { opened = true }
                withAnimation(.easeIn(duration: 0.22)) { coverTurned = true }
                try await Task.sleep(for: .milliseconds(220))
                withAnimation(.easeOut(duration: 0.22)) { insideDown = true }
                try await Task.sleep(for: .milliseconds(250))
                for c in 1...max(total, 1) {
                    try Task.checkCancellation()
                    typed = c
                    onInk(CGFloat(c) / CGFloat(max(total, 1)))
                    try await Task.sleep(for: .milliseconds(rows.isEmpty ? 0 : 30))
                }
                onWritten()
                guard loops else { return }
                // Let it sit, lift the ink, close the book, and start a fresh page.
                try await Task.sleep(for: .seconds(1.2))
                withAnimation(.easeOut(duration: 0.25)) { inkOpacity = 0 }
                try await Task.sleep(for: .milliseconds(250))
                withAnimation(.easeInOut(duration: 0.46)) { opened = false }
                withAnimation(.easeIn(duration: 0.22)) { insideDown = false }
                try await Task.sleep(for: .milliseconds(220))
                withAnimation(.easeOut(duration: 0.22)) { coverTurned = false }
                try await Task.sleep(for: .milliseconds(250))
                typed = 0
                inkOpacity = 1
                onInk(0)
            } while true
        } catch {
            return
        }
    }
}
