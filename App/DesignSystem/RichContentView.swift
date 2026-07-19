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
        guard uiView.attributedText != attributedText else { return }
        uiView.attributedText = attributedText
    }

    // Self-size to the proposed width — without this the text view reports zero/intrinsic sizes
    // that fight the SwiftUI layout inside the reader's scroll view.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fitted.height)
    }
}
