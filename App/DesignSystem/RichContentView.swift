import SwiftUI
import UIKit

private extension UIImage {
    /// Crop only transparent sticker margins; the saved asset and chosen size remain intact.
    func trimmingStickerTransparency() -> UIImage {
        guard let source = cgImage else { return self }
        let width = source.width, height = source.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        var bounds: CGRect?
        pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
            let buffer = bytes.bindMemory(to: UInt8.self)
            var left = width, right = -1, top = height, bottom = -1
            for y in 0..<height { for x in 0..<width where buffer[(y * width + x) * 4 + 3] > 0 {
                left = min(left, x); right = max(right, x)
                top = min(top, y); bottom = max(bottom, y)
            } }
            if right >= left, bottom >= top {
                bounds = CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
            }
        }
        guard let bounds, let cropped = source.cropping(to: bounds) else { return self }
        return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }
}

/// Presentation-only attachment used as a tiny anchor glyph while the image itself floats beside
/// the text. Its source attachment stays in the attributed string and is restored before saving.
final class FloatingAttachmentProxy: NSTextAttachment {
    let source: NSTextAttachment
    lazy var artwork: UIImage? = {
        guard let image = RichTextFormatting.attachmentImage(source) else { return nil }
        return RichTextFormatting.kind(of: source) == .sticker ? image.trimmingStickerTransparency() : image
    }()

    init(source: NSTextAttachment) {
        self.source = source
        super.init(data: source.contents, ofType: source.fileType)
        // UIKit copy/drag exports the presentation attachment directly. Retain its payload
        // and persisted bounds even though layout uses the tiny anchor override below.
        fileWrapper = source.fileWrapper
        bounds = source.bounds
    }

    required init?(coder: NSCoder) {
        source = NSTextAttachment(coder: coder) ?? NSTextAttachment()
        super.init(coder: coder)
    }

    override func image(forBounds imageBounds: CGRect, textContainer: NSTextContainer?,
                        characterIndex charIndex: Int) -> UIImage? { nil }

    override func attachmentBounds(for textContainer: NSTextContainer?,
                                   proposedLineFragment lineFrag: CGRect,
                                   glyphPosition position: CGPoint,
                                   characterIndex charIndex: Int) -> CGRect {
        CGRect(x: 0, y: 0, width: 1, height: 1)
    }
}

/// TextKit may advance a split row using only its final fragment's font metrics. A smaller
/// font to the right of an exclusion would then overlap the taller fragment on the left.
/// Carry the row's largest height through every fragment before TextKit commits the geometry.
private final class AttachmentLineMetrics: NSObject, NSLayoutManagerDelegate {
    func layoutManager(_ layoutManager: NSLayoutManager,
                       shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<CGRect>,
                       lineFragmentUsedRect: UnsafeMutablePointer<CGRect>,
                       baselineOffset: UnsafeMutablePointer<CGFloat>,
                       in textContainer: NSTextContainer, forGlyphRange glyphRange: NSRange) -> Bool {
        guard !textContainer.exclusionPaths.isEmpty, glyphRange.location > 0 else { return false }
        let previous = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location - 1, effectiveRange: nil, withoutAdditionalLayout: true)
        guard abs(previous.minY - lineFragmentRect.pointee.minY) < 0.1,
              previous.height > lineFragmentRect.pointee.height else { return false }
        lineFragmentRect.pointee.size.height = previous.height
        lineFragmentUsedRect.pointee.size.height = max(previous.height, lineFragmentUsedRect.pointee.height)
        return true
    }
}

/// Keeps floating attachment layout in sync across the editable and read-only UITextViews. The
/// attachment character is a one-point anchor; an image subview draws the original asset, while
/// NSTextContainer exclusion paths reserve its area so multiple text lines flow beside it.
final class FloatingAttachmentFlow {
    private struct Item {
        let index: Int
        let proxy: FloatingAttachmentProxy
        let image: UIImage
        let size: CGSize
        let alignment: RichTextFormatting.AttachmentAlignment
    }

    private let lineMetrics = AttachmentLineMetrics()
    private var proxyCache: [ObjectIdentifier: FloatingAttachmentProxy] = [:]
    private var imageViews: [ObjectIdentifier: UIImageView] = [:]
    private var frames: [Int: CGRect] = [:]
    private var lastPresentationSource: NSAttributedString?
    private var lastPresentationWidth: CGFloat = -1
    private var lastPresentation: NSAttributedString?

    func presentationText(from source: NSAttributedString, width: CGFloat) -> NSAttributedString {
        if let lastPresentation, source === lastPresentationSource,
           abs(width - lastPresentationWidth) < 0.5 { return lastPresentation }

        let normalized = persistedText(from: source)
        let fitted = RichTextFormatting.scaleAttachments(in: normalized, toFitWidth: width)
        let mutable = NSMutableAttributedString(attributedString: fitted)
        var liveProxyIDs = Set<ObjectIdentifier>()
        mutable.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutable.length), options: []) { value, range, _ in
            guard let attachment = value as? NSTextAttachment else { return }
            if !RichTextFormatting.isFloating(attachment, containerWidth: width) {
                let style = ((mutable.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
                switch RichTextFormatting.attachmentAlignment(attachment) {
                case .left: style.alignment = .left
                case .center: style.alignment = .center
                case .right: style.alignment = .right
                }
                mutable.addAttribute(.paragraphStyle, value: style, range: range)
                return
            }
            let key = ObjectIdentifier(attachment)
            liveProxyIDs.insert(key)
            let proxy: FloatingAttachmentProxy
            if let cached = proxyCache[key] {
                proxy = cached
            } else {
                proxy = FloatingAttachmentProxy(source: attachment)
                proxyCache[key] = proxy
            }
            mutable.addAttribute(.attachment, value: proxy, range: range)
        }
        proxyCache = proxyCache.filter { liveProxyIDs.contains($0.key) }

        lastPresentationSource = source
        lastPresentationWidth = width
        lastPresentation = mutable
        return mutable
    }

    func persistedText(from presentation: NSAttributedString) -> NSAttributedString {
        guard presentation.length > 0 else { return presentation }
        let mutable = NSMutableAttributedString(attributedString: presentation)
        var replacements: [(NSRange, FloatingAttachmentProxy, [NSAttributedString.Key: Any])] = []
        mutable.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutable.length), options: []) { value, range, _ in
            guard let proxy = value as? FloatingAttachmentProxy else { return }
            var attributes = mutable.attributes(at: range.location, effectiveRange: nil)
            attributes.removeValue(forKey: .attachment)
            replacements.append((range, proxy, attributes))
        }
        for (range, proxy, attributes) in replacements.reversed() {
            let replacement = NSMutableAttributedString(attachment: proxy.source)
            replacement.addAttributes(attributes, range: NSRange(location: 0, length: replacement.length))
            mutable.replaceCharacters(in: range, with: replacement)
        }
        return mutable
    }

    func update(in textView: UITextView, contentWidth proposedWidth: CGFloat? = nil) {
        textView.layoutManager.delegate = lineMetrics
        let inset = textView.textContainerInset
        let width = max(1, proposedWidth ?? (textView.bounds.width - inset.left - inset.right))
        textView.textContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)

        var items: [Item] = []
        let storage = textView.textStorage
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length), options: []) { value, range, _ in
            guard let proxy = value as? FloatingAttachmentProxy,
                  let image = proxy.artwork else { return }
            let size = RichTextFormatting.displaySize(of: proxy.source)
            guard size.width > 0, size.height > 0 else { return }
            items.append(Item(index: range.location, proxy: proxy, image: image, size: size,
                              alignment: RichTextFormatting.attachmentAlignment(proxy.source)))
        }

        let liveIDs = Set(items.map { ObjectIdentifier($0.proxy) })
        for (id, imageView) in imageViews where !liveIDs.contains(id) {
            imageView.removeFromSuperview()
            imageViews.removeValue(forKey: id)
        }
        for item in items {
            let id = ObjectIdentifier(item.proxy)
            let imageView = imageViews[id] ?? {
                let view = UIImageView()
                view.contentMode = .scaleAspectFit
                view.isUserInteractionEnabled = false
                view.backgroundColor = .clear
                textView.addSubview(view)
                imageViews[id] = view
                return view
            }()
            imageView.image = item.image
        }

        // Start each pass from the document's glyph layout, never from selection/caret geometry.
        // Resolve anchors in document order using only the preceding attachments' exclusions.
        textView.textContainer.widthTracksTextView = false
        textView.textContainer.exclusionPaths = []
        let manager = textView.layoutManager
        manager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: storage.length), actualCharacterRange: nil)
        manager.ensureLayout(for: textView.textContainer)
        var paths: [CGRect] = []
        for item in items {
            let glyph = manager.glyphIndexForCharacter(at: item.index)
            var y = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).minY
            let gap: CGFloat = 3
            let reservedWidth = min(width, item.size.width + gap * 2)
            let x = item.alignment == .center ? max(0, (width - reservedWidth) / 2) : (item.alignment == .right ? max(0, width - reservedWidth) : 0)
            var rect = CGRect(x: x, y: y, width: reservedWidth, height: item.size.height + gap * 2)
            for previous in paths where rect.intersects(previous) {
                y = previous.maxY
                rect.origin.y = y
            }
            paths.append(rect)
            textView.textContainer.exclusionPaths = paths.map { UIBezierPath(rect: $0) }
            manager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: storage.length), actualCharacterRange: nil)
            manager.ensureLayout(for: textView.textContainer)
        }

        var updatedFrames: [Int: CGRect] = [:]
        for (offset, item) in items.enumerated() where offset < paths.count {
            let exclusion = paths[offset]
            let imageWidth = min(item.size.width, max(1, exclusion.width - 6))
            let frame = CGRect(x: inset.left + exclusion.minX + (exclusion.width - imageWidth) / 2,
                               y: inset.top + exclusion.minY + 3,
                               width: imageWidth, height: item.size.height)
            imageViews[ObjectIdentifier(item.proxy)]?.frame = frame
            imageViews[ObjectIdentifier(item.proxy)]?.layer.zPosition = 1
            updatedFrames[item.index] = frame
        }
        frames = updatedFrames
        // Exclusions can move glyphs across multiple fragments. Redraw the entire affected
        // text range so old glyph pixels cannot survive in UITextView's rendering cache.
        manager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: storage.length))
        textView.setNeedsDisplay()
    }

    func frame(forAttachmentAt index: Int) -> CGRect? { frames[index] }

    /// One hit test for gesture arbitration and the attachment toolbar, including full-width art.
    func attachmentIndex(at point: CGPoint, in textView: UITextView) -> Int? {
        if let hit = frames.first(where: { $0.value.contains(point) }) { return hit.key }
        let manager = textView.layoutManager
        var hit: Int?
        textView.textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: textView.textStorage.length)) { value, range, stop in
            guard value is NSTextAttachment, !(value is FloatingAttachmentProxy) else { return }
            let glyphs = manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let rect = manager.boundingRect(forGlyphRange: glyphs, in: textView.textContainer)
                .offsetBy(dx: textView.textContainerInset.left, dy: textView.textContainerInset.top)
            if rect.contains(point) { hit = range.location; stop.pointee = true }
        }
        return hit
    }

    func requiredHeight(in textView: UITextView) -> CGFloat {
        var bottom = frames.values.map(\.maxY).max() ?? 0
        let manager = textView.layoutManager
        manager.ensureLayout(for: textView.textContainer)
        textView.textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: textView.textStorage.length)) { value, range, _ in
            guard value is NSTextAttachment, !(value is FloatingAttachmentProxy) else { return }
            let glyphs = manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let rect = manager.boundingRect(forGlyphRange: glyphs, in: textView.textContainer)
            bottom = max(bottom, rect.maxY + textView.textContainerInset.top)
        }
        return bottom > 0 ? bottom + textView.textContainerInset.bottom : 0
    }


}

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
        let tv = UITextView(usingTextLayoutManager: false)
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
        context.coordinator.updateLayout(in: uiView, width: width)
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(fitted.height, context.coordinator.requiredHeight(in: uiView)))
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Sets the text view's content once per (page, width). Fitting attachments to a width builds
    /// fresh attachment objects every time, so the result never compares equal to what's already
    /// shown — re-setting it on every layout pass invalidated layout again and again, which hung
    /// the app (on a white screen) wherever a page was drawn narrower than it was written.
    final class Coordinator {
        private var source: NSAttributedString?
        private var width: CGFloat = -1
        private let attachmentFlow = FloatingAttachmentFlow()

        func show(_ text: NSAttributedString, width: CGFloat, in view: UITextView) {
            guard text !== source || abs(width - self.width) > 0.5 else { return }
            source = text
            self.width = width
            let presentation = attachmentFlow.presentationText(from: text, width: width)
            view.attributedText = presentation
            attachmentFlow.update(in: view, contentWidth: width)
        }

        func requiredHeight(in view: UITextView) -> CGFloat { attachmentFlow.requiredHeight(in: view) }

        func updateLayout(in view: UITextView, width: CGFloat) {
            attachmentFlow.update(in: view, contentWidth: width)
        }
    }
}
