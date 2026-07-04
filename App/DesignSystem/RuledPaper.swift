import SwiftUI

struct RuledPaper<Content: View>: View {
    var lineHeight: CGFloat = 32
    var cornerRadius: CGFloat = 20
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(Palette.cream)
                    Canvas { ctx, size in
                        var y = lineHeight
                        while y < size.height {
                            var p = Path()
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: size.width, y: y))
                            ctx.stroke(p, with: .color(Palette.ink.opacity(0.10)), lineWidth: 1)
                            y += lineHeight
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Palette.ink, lineWidth: 2))
            .shadow(color: Color(hex: "78501E").opacity(0.16), radius: 14, y: 10)
    }
}
