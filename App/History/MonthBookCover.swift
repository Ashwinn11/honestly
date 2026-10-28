import SwiftUI

// MARK: - The book

/// A month as a closed book: cover (the month's newest photo, else its most-used theme), the
/// month's moods along the bottom, and a block of page edges that thickens as pages are written.
/// The book still being written carries a ribbon.
struct MonthBookCover: View {
    let book: MonthBook
    var width: CGFloat = 92
    var locked = false
    /// Shown instead of the saved cover — the cover editor's live preview.
    var lookOverride: CoverLook? = nil
    @Environment(CoverStore.self) private var covers

    init(book: MonthBook, width: CGFloat = 92, locked: Bool = false, lookOverride: CoverLook? = nil) {
        self.book = book
        self.width = width
        self.locked = locked
        self.lookOverride = lookOverride
    }

    var body: some View {
        let w = DesignScale.s(width)
        let h = w * 1.42
        let edge = w * (0.03 + 0.003 * CGFloat(min(book.entries.count, 31)))   // 3% → ~12% of the width
        let look = lookOverride ?? covers.look(for: book)
        let photo = look.photo
        let ink = look.ink
        let coverShape = UnevenRoundedRectangle(topLeadingRadius: w * 0.03, bottomLeadingRadius: w * 0.03,
                                                bottomTrailingRadius: w * 0.09, topTrailingRadius: w * 0.09,
                                                style: .continuous)

        ZStack(alignment: .topLeading) {
            PageEdges()
                .frame(width: edge + w * 0.08, height: h - w * 0.07)
                .offset(x: w - w * 0.08, y: w * 0.035)

            ZStack(alignment: .bottomLeading) {
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                        .frame(width: w, height: h).clipped()
                    LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                } else {
                    look.color
                    CoverDots(color: look.ink.opacity(0.09), spacing: w * 0.11)
                }
                Rectangle().fill(.black.opacity(0.16))                     // the spine's fold
                    .frame(width: w * 0.07)
                    .frame(maxHeight: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: w * 0.025) {
                    Text(verbatim: String(book.year))
                        .font(Fonts.ui(width * 0.075, .heavy)).tracking(width * 0.015)
                    Text(verbatim: HDate.monthName(book.firstOfMonth))
                        .font(Fonts.display(width * 0.165, .heavy))
                        .lineLimit(1).minimumScaleFactor(0.55)
                    if !book.entries.isEmpty && width >= 80 {     // too small to read on a mini book
                        HStack(spacing: w * 0.015) {
                            ForEach(Array(book.entries.suffix(7).enumerated()), id: \.offset) { _, e in
                                MoodFace(mood: e.moodRaw, size: w * 0.085)
                            }
                        }
                        .padding(.top, w * 0.03)
                    }
                }
                .foregroundStyle(ink)
                .padding(.leading, w * 0.14).padding(.trailing, w * 0.06).padding(.bottom, w * 0.1)
            }
            .frame(width: w, height: h)
            .clipShape(coverShape)
            .overlay(coverShape.strokeBorder(Palette.ink, lineWidth: 2))

            if book.isCurrent {
                RibbonShape()
                    .fill(Palette.amber)
                    .overlay(RibbonShape().stroke(Palette.ink, lineWidth: 2))
                    .frame(width: w * 0.1, height: h * 0.3)
                    .offset(x: w * 0.72, y: -w * 0.04)
            }

            if locked {
                PremiumLockBadge(size: w * 0.26)
                    .offset(x: w * 0.66, y: w * 0.08)
            }
        }
        .frame(width: w + edge, height: h, alignment: .topLeading)
        .shadow(color: Palette.warmShadow.opacity(0.22), radius: w * 0.08, x: 0, y: w * 0.07)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: HDate.monthTitle(book.firstOfMonth)))
        .accessibilityHint(locked ? Text("Unlock Premium") : Text(verbatim: ""))
    }
}

/// The stack of page edges showing past the cover's open side.
private struct PageEdges: View {
    var body: some View {
        let shape = UnevenRoundedRectangle(bottomTrailingRadius: 5, topTrailingRadius: 5, style: .continuous)
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Palette.cream))
            var x: CGFloat = 2
            while x < size.width {
                ctx.fill(Path(CGRect(x: x, y: 0, width: 0.75, height: size.height)),
                         with: .color(Palette.hairline))
                x += 2.5
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.ink, lineWidth: 2))
    }
}

/// A quiet dot texture so theme covers read as cloth, not flat UI.
private struct CoverDots: View {
    let color: Color
    let spacing: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let r: CGFloat = max(1, spacing * 0.12)
            var y = spacing / 2
            var row = 0
            while y < size.height {
                var x = spacing / 2 + (row.isMultiple(of: 2) ? 0 : spacing / 2)
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(color))
                    x += spacing
                }
                y += spacing
                row += 1
            }
        }
    }
}

/// A bookmark ribbon with a V-notched tail.
private struct RibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.width * 0.7))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

extension PageTheme {
    /// Book-cover colour for a month whose pages mostly use this theme — a deeper take on the
    /// page wash so covers read as covers on the shelf, plus the ink that stays legible on it.
    var cover: (color: Color, ink: Color) {
        switch self {
        case .paper:        return (Color(hex: "E9DCC3"), Palette.ink)
        case .grid:         return (Color(hex: "DAD5C5"), Palette.ink)
        case .dots:         return (Color(hex: "E8D5B5"), Palette.ink)
        case .linen:        return (Color(hex: "CFBE9F"), Palette.ink)
        case .ledger:       return (Color(hex: "BCC6D2"), Palette.ink)
        case .meadow:       return (Color(hex: "AFC895"), Palette.ink)
        case .mushroomWood: return (Color(hex: "C9A27E"), Palette.ink)
        case .library:      return (Color(hex: "7E4F33"), Color(hex: "FFF7EA"))
        case .inkGold:      return (Color(hex: "2F2A24"), Color(hex: "E9CB7A"))
        case .midnight:     return (Color(hex: "3F4589"), Color(hex: "F3F0FF"))
        case .stargazer:    return (Color(hex: "2F3654"), Color(hex: "EEF0FA"))
        case .tide:         return (Color(hex: "8DBCCB"), Palette.ink)
        case .seaGlass:     return (Color(hex: "A3CFBD"), Palette.ink)
        case .ballet:       return (Color(hex: "EDBAC5"), Palette.ink)
        case .cherry:       return (Color(hex: "B0423B"), Color(hex: "FFF3F1"))
        case .sunshine:     return (Color(hex: "F2C35B"), Palette.ink)
        case .bubblegum:    return (Color(hex: "EFA8D1"), Palette.ink)
        }
    }
}
