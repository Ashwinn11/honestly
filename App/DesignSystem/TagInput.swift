import SwiftUI

private enum TagMetrics {
    static var height: CGFloat { DesignScale.s(36) }
}

/// A rounded "# tag" pill — matches the app's existing chip styling. Pass `onRemove` for an
/// editable "×" affordance (the ritual, writing today's page); omit it for read-only display
/// (`EntryDetailView`, a past page).
struct TagChip: View {
    let text: String
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 5) {
            Text("#\(text)")
                .font(Fonts.ui(12.5, .heavy))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Palette.inkSofter)
                }
                .buttonStyle(PressableStyle(scale: 0.85))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: TagMetrics.height)
        .background(Palette.cream, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.outlineSoft, lineWidth: 1.5))
    }
}

/// Shared normalization and limit for typed and reused tags.
enum TagEditing {
    static let maxTags = 5

    static func commit(draft: inout String, into tags: inout [String]) {
        let cleaned = draft.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        draft = ""
        guard !cleaned.isEmpty, tags.count < maxTags, !tags.contains(cleaned) else { return }
        tags.append(cleaned)
    }
}

/// Read-only chip row — past entries in `EntryDetailView`. Only rendered when tags exist.
struct TagRow: View {
    let tags: [String]
    @Environment(\.layoutDirection) private var direction

    var body: some View {
        if !tags.isEmpty {
            TagFlowLayout(rightToLeft: direction == .rightToLeft) {
                ForEach(tags, id: \.self) { TagChip(text: $0) }
            }
        }
    }
}

/// Content-sized chips with a fixed gap; long rows wrap instead of stretching into columns.
struct TagFlowLayout: Layout {
    var rightToLeft = false
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (view, rect) in zip(subviews, result.frames) {
            let x = rightToLeft ? bounds.maxX - rect.maxX : bounds.minX + rect.minX
            view.place(at: CGPoint(x: x, y: bounds.minY + rect.minY), anchor: .topLeading,
                       proposal: ProposedViewSize(rect.size))
        }
    }

    private func arrange(width proposed: CGFloat?, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let natural = subviews.map { $0.sizeThatFits(.unspecified) }
        let intrinsic = natural.reduce(0) { $0 + $1.width } + spacing * CGFloat(max(0, natural.count - 1))
        let width = max(0, proposed.flatMap { $0.isFinite ? $0 : nil } ?? intrinsic)
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for (index, view) in subviews.enumerated() {
            let size = natural[index].width > width
                ? view.sizeThatFits(ProposedViewSize(width: width, height: nil)) : natural[index]
            let itemWidth = min(width, size.width)
            if x > 0 && x + itemWidth > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: itemWidth, height: size.height))
            x += itemWidth + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), frames)
    }
}
