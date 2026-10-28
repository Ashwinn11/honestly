import SwiftUI
import UIKit

/// Renders a formatted `NSAttributedString` read-only, via a non-editable, non-scrolling
/// `UITextView` — the only renderer that draws *everything* the editor can produce (paragraph
/// alignment, list prefixes, arbitrary fonts, attachment bounds like minimized images and
/// stickers) exactly as stored in the RTFD.
///
/// Replaces the old manual attribute-walker (`RichContentRenderer`): SwiftUI `Text` has no
/// paragraph-style rendering at all, so alignment and alignment-following minimized images were
/// impossible there, and every new editor attribute needed hand-mapping. Here they're free.
struct RichContentView: UIViewRepresentable {
    let attributedText: NSAttributedString

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.isOpaque = false
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.adjustsFontForContentSizeCategory = false
        tv.attributedText = attributedText
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let contentWidth = uiView.bounds.width > 0
            ? uiView.bounds.width
            : Metrics.maxContentWidth - Metrics.pageHorizontalInset * 2
        context.coordinator.show(attributedText, width: contentWidth, in: uiView)
    }

    // Self-size to the proposed width — without this the text view reports zero/intrinsic sizes
    // that fight the SwiftUI layout inside the reader's scroll view.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        context.coordinator.show(attributedText, width: width, in: uiView)
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fitted.height)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Sets the text view's content once per (page, width). Fitting attachments to a width builds
    /// fresh attachment objects every time, so the result never compares equal to what's already
    /// shown — re-setting it on every layout pass invalidated layout again and again, which hung
    /// the app (on a white screen) wherever a page was drawn narrower than it was written.
    final class Coordinator {
        private var source: NSAttributedString?
        private var width: CGFloat = -1

        func show(_ text: NSAttributedString, width: CGFloat, in view: UITextView) {
            guard text !== source || abs(width - self.width) > 0.5 else { return }
            source = text
            self.width = width
            view.attributedText = RichTextFormatting.scaleAttachments(in: text, toFitWidth: width)
        }
    }
}
