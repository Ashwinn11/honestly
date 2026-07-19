import SwiftUI
import UIKit

/// Tap-to-edit controls for inline attachments: tapping a photo/doodle or sticker in the editor
/// pins a small two-button bar to it — ✕ (remove) plus a resize action (photos: full ↔ minimized;
/// stickers: step through the preset sizes). Owned by `RichTextEditor.Coordinator`.
///
/// The bar is added as a `UITextView` subview, which puts it in the scroll *content* coordinate
/// space — the same space `NSLayoutManager` rects are in — so it rides along with the attachment
/// when the editor scrolls, no offset math needed. Edits flow out through the same
/// `attributedText` binding path as toolbar commands; after a resize the bar re-anchors itself to
/// the attachment's new frame (via `textDidChangeExternally`), after a delete it just goes away.
final class AttachmentEditController {
    private weak var bar: UIView?
    private var attachmentIndex: Int?
    private var expectingRefresh = false
    private var apply: ((NSAttributedString) -> Void)?

    func handleTap(at point: CGPoint, in textView: UITextView,
                   apply: @escaping (NSAttributedString) -> Void) {
        self.apply = apply
        var containerPoint = point
        containerPoint.x -= textView.textContainerInset.left
        containerPoint.y -= textView.textContainerInset.top
        let layoutManager = textView.layoutManager
        let index = layoutManager.characterIndex(for: containerPoint, in: textView.textContainer,
                                                 fractionOfDistanceBetweenInsertionPoints: nil)
        guard index < textView.textStorage.length,
              textView.textStorage.attribute(.attachment, at: index, effectiveRange: nil) is NSTextAttachment,
              attachmentRect(at: index, in: textView).insetBy(dx: -8, dy: -8).contains(point)
        else {
            dismiss()
            return
        }
        Haptics.select()
        show(forAttachmentAt: index, in: textView)
    }

    func dismiss() {
        bar?.removeFromSuperview()
        bar = nil
        attachmentIndex = nil
        expectingRefresh = false
    }

    /// SwiftUI pushed a new string into the text view. If that was our own resize, re-anchor the
    /// bar to the attachment's new frame once layout settles; any other external change
    /// invalidates the index, so the bar goes away.
    func textDidChangeExternally(in textView: UITextView) {
        guard bar != nil else { return }
        guard expectingRefresh, let index = attachmentIndex else {
            dismiss()
            return
        }
        expectingRefresh = false
        DispatchQueue.main.async { [weak self, weak textView] in
            guard let self, let textView else { return }
            self.show(forAttachmentAt: index, in: textView)
        }
    }

    // MARK: - Internals

    private func show(forAttachmentAt index: Int, in textView: UITextView) {
        dismiss()
        guard index < textView.textStorage.length,
              let attachment = textView.textStorage.attribute(.attachment, at: index,
                                                              effectiveRange: nil) as? NSTextAttachment
        else { return }

        let kind = RichTextFormatting.kind(of: attachment)
        let containerWidth = contentWidth(of: textView)
        let isFull = RichTextFormatting.isFullSize(attachment, containerWidth: containerWidth)

        let bar = AttachmentEditBar(
            resizeIcon: kind == .sticker
                ? "arrow.up.left.and.arrow.down.right"
                : (isFull ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"),
            onDelete: { [weak self, weak textView] in
                guard let self, let textView else { return }
                Haptics.tap()
                let newText = RichTextFormatting.removeAttachment(at: index, in: textView.attributedText)
                self.dismiss()
                self.apply?(newText)
            },
            onResize: { [weak self, weak textView] in
                guard let self, let textView else { return }
                Haptics.select()
                let newText = kind == .sticker
                    ? RichTextFormatting.cycleStickerSize(at: index, in: textView.attributedText)
                    : RichTextFormatting.toggleImageSize(at: index,
                                                          containerWidth: self.contentWidth(of: textView),
                                                          in: textView.attributedText)
                self.expectingRefresh = true
                self.apply?(newText)
            })

        let rect = attachmentRect(at: index, in: textView)
        let size = bar.intrinsicContentSize
        var origin = CGPoint(x: rect.maxX - size.width, y: rect.minY - size.height - 6)
        // Keep the bar on the page horizontally, and drop it inside the attachment's top edge
        // when the attachment starts at the very top of the text (nowhere above to float).
        origin.x = max(textView.textContainerInset.left,
                       min(origin.x, textView.bounds.width - size.width - textView.textContainerInset.right))
        if origin.y < 2 { origin.y = rect.minY + 6 }
        bar.frame = CGRect(origin: origin, size: size)

        textView.addSubview(bar)
        self.bar = bar
        self.attachmentIndex = index
    }

    private func attachmentRect(at index: Int, in textView: UITextView) -> CGRect {
        let layoutManager = textView.layoutManager
        let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: index, length: 1),
                                                  actualCharacterRange: nil)
        layoutManager.ensureLayout(forGlyphRange: glyphRange)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer)
        rect.origin.x += textView.textContainerInset.left
        rect.origin.y += textView.textContainerInset.top
        return rect
    }

    private func contentWidth(of textView: UITextView) -> CGFloat {
        textView.bounds.width - textView.textContainerInset.left - textView.textContainerInset.right
    }
}

/// The floating two-tile bar itself — UIKit because it lives inside the UITextView, styled to
/// match the SwiftUI toolbar tiles (paper fill, soft outline, ink icons).
final class AttachmentEditBar: UIView {
    private static let tile: CGFloat = 34
    private static let spacing: CGFloat = 6
    private static let padding: CGFloat = 5

    init(resizeIcon: String, onDelete: @escaping () -> Void, onResize: @escaping () -> Void) {
        super.init(frame: .zero)
        backgroundColor = UIColor(Palette.cream)
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        layer.borderWidth = 1.2
        layer.borderColor = UIColor(Palette.outlineSoft).cgColor
        layer.shadowColor = UIColor(Color(hex: "78501E")).cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 4)

        let stack = UIStackView(arrangedSubviews: [
            Self.tileButton(icon: resizeIcon, action: onResize),
            Self.tileButton(icon: "xmark", action: onDelete),
        ])
        stack.axis = .horizontal
        stack.spacing = Self.spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Self.padding),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.padding),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.padding),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.padding),
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: CGSize {
        CGSize(width: Self.tile * 2 + Self.spacing + Self.padding * 2,
               height: Self.tile + Self.padding * 2)
    }

    private static func tileButton(icon: String, action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: icon,
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .bold))
        config.baseForegroundColor = UIColor(Palette.ink)
        let button = UIButton(configuration: config, primaryAction: UIAction { _ in action() })
        button.backgroundColor = UIColor(Palette.paper)
        button.layer.cornerRadius = 9
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = 1.2
        button.layer.borderColor = UIColor(Palette.outlineSoft).cgColor
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: tile),
            button.heightAnchor.constraint(equalToConstant: tile),
        ])
        return button
    }
}
