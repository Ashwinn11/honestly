import SwiftUI

/// White rounded "paper" with evenly-spaced rule lines behind its content. Shared by the ritual's
/// journal editor and the entry-detail journal, so writing looks the same when written and read.
struct RuledPaper<Content: View>: View {
    var lineHeight: CGFloat = 32
    var cornerRadius: CGFloat = 20
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(.white)
                    Canvas { ctx, size in
                        var y = lineHeight
                        while y < size.height {
                            var p = Path()
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: size.width, y: y))
                            ctx.stroke(p, with: .color(Palette.ink.opacity(0.07)), lineWidth: 1)
                            y += lineHeight
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color(hex: "78501E").opacity(0.07), radius: 11, y: 8)
    }
}
