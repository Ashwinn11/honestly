import SwiftUI

struct JournalPageSurface<Content: View>: View {
    var lineHeight: CGFloat = 32
    var cornerRadius: CGFloat = 22
    var showsMargin: Bool = true
    var showsBinderHoles: Bool = false
    var shadowRadius: CGFloat = 14
    var shadowOpacity: Double = 0.14
    var bordered: Bool = true   // false = full-bleed page (no card stroke/shadow, e.g. Ritual/EntryDetail)
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content()
            .background {
                ZStack(alignment: .leading) {
                    shape.fill(Palette.cream)

                    JournalRuleLayer(lineHeight: lineHeight, showsMargin: showsMargin)
                        .clipShape(shape)

                    if showsBinderHoles {
                        LinearGradient(colors: [Palette.ink.opacity(0.08), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: 34)
                    }

                    LinearGradient(colors: [.white.opacity(0.55), .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 26)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
            .clipShape(shape)
            .overlay(bordered ? AnyView(shape.stroke(Palette.ink, lineWidth: 2)) : AnyView(EmptyView()))
            .overlay(alignment: .leading) {
                if showsBinderHoles {
                    JournalBinderHoles()
                        .padding(.leading, 10)
                }
            }
            .shadow(color: Color(hex: "78501E").opacity(bordered ? shadowOpacity : 0),
                    radius: shadowRadius, x: 0, y: shadowRadius * 0.7)
    }
}

private struct JournalRuleLayer: View {
    var lineHeight: CGFloat
    var showsMargin: Bool

    var body: some View {
        Canvas { ctx, size in
            var y = lineHeight
            while y < size.height {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(line, with: .color(Palette.ink.opacity(0.09)), lineWidth: 1)
                y += lineHeight
            }

            guard showsMargin else { return }
            var margin = Path()
            margin.move(to: CGPoint(x: 54, y: 0))
            margin.addLine(to: CGPoint(x: 54, y: size.height))
            ctx.stroke(margin, with: .color(Palette.danger.opacity(0.24)), lineWidth: 1)
        }
    }
}

private struct JournalBinderHoles: View {
    var body: some View {
        VStack(spacing: 38) {
            ForEach(0..<4, id: \.self) { _ in
                Circle()
                    .fill(Palette.paper)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Palette.ink.opacity(0.18), lineWidth: 1))
                    .shadow(color: Palette.ink.opacity(0.06), radius: 2, y: 1)
            }
        }
        .frame(width: 18)
        .frame(maxHeight: .infinity)
        .padding(.vertical, 30)
        .allowsHitTesting(false)
    }
}

struct RuledPaper<Content: View>: View {
    var lineHeight: CGFloat = 32
    var cornerRadius: CGFloat = 20
    @ViewBuilder var content: () -> Content

    var body: some View {
        JournalPageSurface(lineHeight: lineHeight,
                           cornerRadius: cornerRadius,
                           showsMargin: true,
                           showsBinderHoles: false) {
            content()
        }
    }
}
