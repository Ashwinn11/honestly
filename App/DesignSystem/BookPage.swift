import SwiftUI
import UIKit

extension Metrics {
    /// Width of the page edges showing past a small book's open side (see `BookPageStack`).
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
                         with: .color(Palette.hairline))
                x += 2.2
            }
        }
        .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 10, topTrailingRadius: 10, style: .continuous))
        .accessibilityHidden(true)
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
