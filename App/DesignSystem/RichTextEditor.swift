import SwiftUI
import UIKit
import UniformTypeIdentifiers

extension Notification.Name {
    static let editorApplyDefaultTransform  = Notification.Name("editorApplyDefaultTransform")
    static let journalEntryDidUpdate        = Notification.Name("journalEntryDidUpdate")
    static let editorUndo                   = Notification.Name("editorUndo")
    static let editorRedo                   = Notification.Name("editorRedo")
    /// Carries `transform:(NSAttributedString,NSRange)->NSAttributedString` + `range:NSRange`.
    /// Coordinator applies via textStorage + registers undo — never touches the SwiftUI binding.
    static let editorApplyFormatToStorage   = Notification.Name("editorApplyFormatToStorage")
}

/// A `UITextView` bridge for rich formatting (bold/italic/underline/font/size/color/alignment/
/// lists) plus inline images, doodles and stickers — SwiftUI's own `TextEditor` has no
/// attributed-text support at this app's iOS 18 minimum, but `UITextView`/`NSAttributedString`
/// have supported all of this natively for years.
struct RichTextEditor: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var isEditingAllowed: Bool          // premium.isPremium — locks rich formatting at the UIKit level
    @Binding var selectedRange: NSRange
    var placeholder: String = ""

    static let defaultFont: UIFont =
        UIFont(name: "Nunito-Regular", size: DesignScale.s(16)) ?? .systemFont(ofSize: DesignScale.s(16))

    /// Default paragraph style — consistent 4 pt line spacing for all fonts; prevents the
    /// layout engine from packing lines so tight that tall ascenders/descenders clip adjacent lines.
    static let defaultParagraphStyle: NSParagraphStyle = {
        let s = NSMutableParagraphStyle()
        s.lineSpacing = 4
        return s
    }()

    static var defaultAttributes: [NSAttributedString.Key: Any] {
        [.font: defaultFont,
         .foregroundColor: Palette.inkUI,
         .paragraphStyle: defaultParagraphStyle]
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.isOpaque = false
        tv.textContainerInset = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
        tv.textContainer.lineFragmentPadding = 0
        tv.tintColor = UIColor(Palette.amber)
        tv.typingAttributes = Self.defaultAttributes
        tv.allowsEditingTextAttributes = isEditingAllowed
        tv.smartInsertDeleteType = .no
        tv.attributedText = attributedText
        tv.delegate = context.coordinator

        // Attachment tap-to-edit (✕ / resize bar) — fires alongside the text view's own tap
        // handling (caret placement), so it must not cancel or exclude it.
        tv.delaysContentTouches = false  // UITextView is a scroll view — without this it delays
        // touches to subviews, causing the attachment edit bar's UIButtons to fire unreliably.

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleAttachmentTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        tv.addGestureRecognizer(tap)

        let label = UILabel()
        // Not SwiftUI here, so `Text(loc:)` doesn't apply — do the String Catalog lookup directly
        // (matching `AffirmationNudge.swift`'s pattern for non-SwiftUI localized strings).
        label.text = String(localized: String.LocalizationValue(placeholder))
        label.font = Self.defaultFont
        label.textColor = UIColor(Palette.inkSofter)
        label.numberOfLines = 0
        label.isHidden = !attributedText.string.isEmpty
        label.translatesAutoresizingMaskIntoConstraints = false
        tv.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: tv.topAnchor, constant: tv.textContainerInset.top),
            label.leadingAnchor.constraint(equalTo: tv.leadingAnchor, constant: tv.textContainerInset.left),
            label.trailingAnchor.constraint(equalTo: tv.trailingAnchor, constant: -tv.textContainerInset.right),
        ])
        context.coordinator.placeholderLabel = label
        context.coordinator.textView = tv

        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.isApplyingSwiftUIUpdate = true
        defer { context.coordinator.isApplyingSwiftUIUpdate = false }
        uiView.backgroundColor = .clear
        uiView.isOpaque = false
        uiView.allowsEditingTextAttributes = isEditingAllowed
        uiView.smartInsertDeleteType = .no
        context.coordinator.placeholderLabel?.text = String(localized: String.LocalizationValue(placeholder))
        context.coordinator.placeholderLabel?.isHidden = !attributedText.string.isEmpty
        let selection = uiView.selectedRange
        // Only replace textStorage when content actually differs — setting `attributedText` via the
        // property setter unconditionally resets NSUndoManager and triggers a full re-layout on
        // every SwiftUI re-render (including after every keystroke). Going through textStorage
        // directly with an equality guard preserves the undo stack and avoids the re-layout flash
        // that causes line-overlap visual artefacts.
        if uiView.attributedText != attributedText {
            uiView.textStorage.beginEditing()
            uiView.textStorage.setAttributedString(attributedText)
            uiView.textStorage.endEditing()
        }
        let len = (uiView.text as NSString).length
        let clampedLocation = min(selection.location, len)
        let clampedLength = min(selection.length, max(0, len - clampedLocation))
        uiView.selectedRange = NSRange(location: clampedLocation, length: clampedLength)

        context.coordinator.textView = uiView
        context.coordinator.updateTypingAttributes(in: uiView, selection: uiView.selectedRange)

        context.coordinator.textDidChangeExternally(uiView)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: RichTextEditor
        var isApplyingSwiftUIUpdate = false
        weak var placeholderLabel: UILabel?
        weak var textView: UITextView?
        var defaultAttributes: [NSAttributedString.Key: Any] = RichTextEditor.defaultAttributes
        private let attachmentEditor = AttachmentEditController()
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
            super.init()
            let nc = NotificationCenter.default
            nc.addObserver(self, selector: #selector(handleDefaultTransform(_:)),
                           name: .editorApplyDefaultTransform, object: nil)
            nc.addObserver(self, selector: #selector(handleUndo),
                           name: .editorUndo, object: nil)
            nc.addObserver(self, selector: #selector(handleRedo),
                           name: .editorRedo, object: nil)
            nc.addObserver(self, selector: #selector(handleFormatToStorage(_:)),
                           name: .editorApplyFormatToStorage, object: nil)
        }

        // MARK: Snapshot-based undo — captures the entire attributed string before each
        // formatting change, registers the reverse as an undo action, and symmetrically
        // re-registers redo inside the undo handler so the stack stays coherent.
        func applySnapshot(_ newText: NSAttributedString) {
            guard let tv = textView else { return }
            let old = NSAttributedString(attributedString: tv.textStorage)
            guard newText != old else { return }
            tv.undoManager?.registerUndo(withTarget: self) { [weak tv] target in
                guard let tv else { return }
                // Undo: restore old. Inside the handler NSUndoManager auto-captures this
                // registerUndo call as the redo action for the inverse direction.
                target.applySnapshot(old)
                // Force UI refresh after undo
                target.textViewDidChange(tv)
            }
            tv.textStorage.beginEditing()
            tv.textStorage.setAttributedString(newText)
            tv.textStorage.endEditing()
            textViewDidChange(tv)
        }

        @objc private func handleFormatToStorage(_ notification: Notification) {
            guard let transform = notification.userInfo?["transform"] as? (NSAttributedString, NSRange) -> NSAttributedString,
                  let rangeValue = notification.userInfo?["range"] as? NSRange,
                  let tv = textView else { return }
            let old = NSAttributedString(attributedString: tv.textStorage)
            let new = transform(old, rangeValue)
            applySnapshot(new)
        }

        func updateTypingAttributes(in textView: UITextView, selection: NSRange) {
            let len = (textView.text as NSString).length
            if selection.length == 0 {
                if selection.location == len {
                    textView.typingAttributes = defaultAttributes
                } else if len > 0 {
                    let attrLoc = max(0, min(selection.location > 0 ? selection.location - 1 : 0, len - 1))
                    textView.typingAttributes = textView.textStorage.attributes(at: attrLoc, effectiveRange: nil)
                }
            }
        }

        @objc private func handleDefaultTransform(_ notification: Notification) {
            guard let transform = notification.userInfo?["transform"] as? (NSAttributedString, NSRange) -> NSAttributedString else { return }
            let dummy = NSAttributedString(string: " ", attributes: defaultAttributes)
            let updated = transform(dummy, NSRange(location: 0, length: 1))
            if updated.length > 0 {
                defaultAttributes = updated.attributes(at: 0, effectiveRange: nil)
                if let textView, textView.selectedRange.length == 0 {
                    textView.typingAttributes = defaultAttributes
                }
            }
        }

        @objc private func handleUndo() { textView?.undoManager?.undo() }
        @objc private func handleRedo() { textView?.undoManager?.redo() }



        func textViewDidChange(_ textView: UITextView) {
            attachmentEditor.dismiss()   // any text mutation can shift attachment indexes
            placeholderLabel?.isHidden = !(textView.text ?? "").isEmpty
            guard !isApplyingSwiftUIUpdate else { return }
            let attributedText = NSAttributedString(attributedString: textView.attributedText ?? NSAttributedString())
            guard parent.attributedText != attributedText else { return }
            parent.attributedText = attributedText
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isApplyingSwiftUIUpdate else { return }
            let selectedRange = textView.selectedRange
            updateTypingAttributes(in: textView, selection: selectedRange)
            guard parent.selectedRange != selectedRange else { return }
            parent.selectedRange = selectedRange
        }

        /// SwiftUI replaced the text (toolbar command or attachment-bar action) — let the edit bar
        /// re-anchor itself if it was mid-interaction, or dismiss otherwise.
        func textDidChangeExternally(_ textView: UITextView) {
            attachmentEditor.textDidChangeExternally(in: textView)
        }

        // MARK: List continuation — Return inside a list item continues it (numbered items count
        // up); Return on an *empty* item strips the prefix and ends the list, matching every
        // notes-style editor.
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange,
                      replacementText text: String) -> Bool {
            guard text == "\n" else { return true }
            let ns = textView.text as NSString
            guard range.location <= ns.length else { return true }
            let paraRange = ns.paragraphRange(for: NSRange(location: range.location, length: 0))
            let paragraph = ns.substring(with: paraRange).trimmingCharacters(in: .newlines)
            guard let item = ListKind.parseItem(paragraph) else { return true }

            if paragraph.dropFirst(item.prefix.count).trimmingCharacters(in: .whitespaces).isEmpty {
                let prefixRange = NSRange(location: paraRange.location, length: (item.prefix as NSString).length)
                textView.textStorage.replaceCharacters(in: prefixRange, with: "")
                textView.selectedRange = NSRange(location: paraRange.location, length: 0)
                textViewDidChange(textView)
                return false
            }

            let nextPrefix = item.kind.prefix(number: (item.number ?? 0) + 1)
            let insertion = NSAttributedString(string: "\n" + nextPrefix, attributes: textView.typingAttributes)
            textView.textStorage.replaceCharacters(in: range, with: insertion)
            textView.selectedRange = NSRange(location: range.location + insertion.length, length: 0)
            textViewDidChange(textView)
            return false
        }

        // MARK: Attachment tap-to-edit
        @objc func handleAttachmentTap(_ gesture: UITapGestureRecognizer) {
            guard let tv = gesture.view as? UITextView else { return }
            attachmentEditor.handleTap(at: gesture.location(in: tv), in: tv) { [weak self] newText in
                guard let self else { return }
                self.parent.attributedText = newText
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}

// MARK: - Formatting commands — pure transforms over (text, range), applied by the toolbar

enum RichTextFormatting {
    static func toggleBold(_ text: NSAttributedString, range: NSRange) -> NSAttributedString {
        toggleTrait(.traitBold, in: text, range: range)
    }

    static func toggleItalic(_ text: NSAttributedString, range: NSRange) -> NSAttributedString {
        toggleTrait(.traitItalic, in: text, range: range)
    }

    private static func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits,
                                     in text: NSAttributedString, range: NSRange) -> NSAttributedString {
        guard range.length > 0 else { return text }
        let mutable = NSMutableAttributedString(attributedString: text)
        // Industry standard: if ALL runs in the range already carry the trait, remove it;
        // if even one run lacks the trait, add it to all ("smart bold" — same as Word/Notes/Bear).
        var allHaveTrait = true
        mutable.enumerateAttribute(.font, in: range, options: []) { value, _, _ in
            let font = (value as? UIFont) ?? RichTextEditor.defaultFont
            if !font.fontDescriptor.symbolicTraits.contains(trait) { allHaveTrait = false }
        }
        let turningOn = !allHaveTrait
        mutable.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
            let font = (value as? UIFont) ?? RichTextEditor.defaultFont
            if let resolved = turningOn ? font.addingTrait(trait) : font.removingTrait(trait) {
                mutable.addAttribute(.font, value: resolved, range: subrange)
            }
        }
        return mutable
    }

    static func toggleUnderline(_ text: NSAttributedString, range: NSRange) -> NSAttributedString {
        guard range.length > 0 else { return text }
        let mutable = NSMutableAttributedString(attributedString: text)
        let isUnderlined = ((text.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int) ?? 0) != 0
        mutable.addAttribute(.underlineStyle,
                              value: isUnderlined ? 0 : NSUnderlineStyle.single.rawValue,
                              range: range)
        return mutable
    }

    static func setTextColor(_ color: UIColor, in text: NSAttributedString, range: NSRange) -> NSAttributedString {
        guard range.length > 0 else { return text }
        let mutable = NSMutableAttributedString(attributedString: text)
        mutable.addAttribute(.foregroundColor, value: color, range: range)
        return mutable
    }

    /// Swaps the font family over `range`, preserving each run's size and bold/italic traits.
    /// Uses the two-step approach: (1) system `withSymbolicTraits` for system fonts,
    /// (2) explicit `addingTrait` (which consults `FontChoice.boldFontName`) for custom fonts.
    static func setFont(_ choice: FontChoice, in text: NSAttributedString, range: NSRange) -> NSAttributedString {
        guard range.length > 0 else { return text }
        let mutable = NSMutableAttributedString(attributedString: text)
        mutable.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
            let old = (value as? UIFont) ?? RichTextEditor.defaultFont
            let base = choice.uiFont(size: old.pointSize)
            var newFont = base
            let keepTraits = old.fontDescriptor.symbolicTraits.intersection([.traitBold, .traitItalic])
            if !keepTraits.isEmpty {
                // Step 1: system fonts — withSymbolicTraits succeeds
                if let descriptor = base.fontDescriptor.withSymbolicTraits(
                        base.fontDescriptor.symbolicTraits.union(keepTraits)) {
                    newFont = UIFont(descriptor: descriptor, size: old.pointSize)
                } else {
                    // Step 2: custom bundled fonts (Nunito, Shantell Sans) — use explicit lookups
                    for trait: UIFontDescriptor.SymbolicTraits in [.traitBold, .traitItalic] {
                        if keepTraits.contains(trait), let promoted = newFont.addingTrait(trait) {
                            newFont = promoted
                        }
                    }
                }
            }
            mutable.addAttribute(.font, value: newFont, range: subrange)
        }
        return mutable
    }

    /// Applies a size preset over `range`, preserving family/traits (`withSize` keeps the descriptor).
    static func setTextSize(_ size: TextSize, in text: NSAttributedString, range: NSRange) -> NSAttributedString {
        guard range.length > 0 else { return text }
        let mutable = NSMutableAttributedString(attributedString: text)
        mutable.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
            let font = (value as? UIFont) ?? RichTextEditor.defaultFont
            mutable.addAttribute(.font, value: font.withSize(size.points), range: subrange)
        }
        return mutable
    }

    // MARK: Paragraph-level commands — work from a bare caret by expanding to the paragraph

    /// The paragraph range(s) covering `range` — what alignment/list/size commands operate on
    /// when there's no selection.
    static func paragraphRange(in text: NSAttributedString, for range: NSRange) -> NSRange {
        let ns = text.string as NSString
        guard ns.length > 0 else { return NSRange(location: 0, length: 0) }
        let location = min(range.location, ns.length)
        let length = min(range.length, ns.length - location)
        return ns.paragraphRange(for: NSRange(location: location, length: length))
    }

    static func setAlignment(_ alignment: NSTextAlignment, in text: NSAttributedString,
                             range: NSRange) -> NSAttributedString {
        let paraRange = paragraphRange(in: text, for: range)
        guard paraRange.length > 0 else { return text }
        let mutable = NSMutableAttributedString(attributedString: text)
        mutable.enumerateAttribute(.paragraphStyle, in: paraRange, options: []) { value, subrange, _ in
            let style = ((value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle)
                ?? NSMutableParagraphStyle()
            style.alignment = alignment
            // Reset stale min/max line heights — these can accumulate from mixed-size paragraphs
            // and cause overlap when a previously-H1 paragraph style is applied to Body text.
            style.minimumLineHeight = 0
            style.maximumLineHeight = 0
            // Carry the default line spacing so text always breathes consistently.
            if style.lineSpacing < 4 { style.lineSpacing = 4 }
            mutable.addAttribute(.paragraphStyle, value: style, range: subrange)
        }
        return mutable
    }

    /// Current alignment at the caret/selection — drives the toolbar's cycle button. `.natural`
    /// reads as `.left` (this app ships LTR-only strings).
    static func alignment(in text: NSAttributedString, at range: NSRange) -> NSTextAlignment {
        guard text.length > 0 else { return .left }
        let location = min(range.location, text.length - 1)
        let style = text.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
        let alignment = style?.alignment ?? .left
        return alignment == .natural ? .left : alignment
    }

    /// Toggles a list prefix on every paragraph the selection touches: if they're all already
    /// `kind`, the prefixes come off; otherwise any other list prefix is swapped out for `kind`'s
    /// (numbered items count 1, 2, 3… down the selection). Prefixes are plain text, so they
    /// serialize in the RTFD with zero special handling anywhere else.
    static func toggleList(_ kind: ListKind, in text: NSAttributedString, range: NSRange) -> NSAttributedString {
        let paraRange = paragraphRange(in: text, for: range)
        guard paraRange.length > 0 else { return text }
        let ns = text.string as NSString
        var paragraphs: [NSRange] = []
        ns.enumerateSubstrings(in: paraRange, options: [.byParagraphs, .substringNotRequired]) { _, subrange, _, _ in
            paragraphs.append(subrange)
        }
        let nonEmpty = paragraphs.filter { $0.length > 0 }
        guard !nonEmpty.isEmpty else { return text }

        let allAlready = nonEmpty.allSatisfy { ListKind.parseItem(ns.substring(with: $0))?.kind == kind }
        let mutable = NSMutableAttributedString(attributedString: text)
        var delta = 0
        var number = 1
        for paragraph in paragraphs {
            guard paragraph.length > 0 else { continue }
            let location = paragraph.location + delta
            let current = (mutable.string as NSString).substring(
                with: NSRange(location: location, length: paragraph.length))
            if let existing = ListKind.parseItem(current) {
                let prefixLength = (existing.prefix as NSString).length
                mutable.replaceCharacters(in: NSRange(location: location, length: prefixLength), with: "")
                delta -= prefixLength
            }
            guard !allAlready else { continue }
            let prefix = kind.prefix(number: number)
            mutable.insert(NSAttributedString(string: prefix, attributes: prefixAttributes(in: mutable, at: location)),
                           at: location)
            delta += (prefix as NSString).length
            number += 1
        }
        return mutable
    }

    private static func prefixAttributes(in text: NSAttributedString, at location: Int) -> [NSAttributedString.Key: Any] {
        guard text.length > 0 else { return RichTextEditor.defaultAttributes }
        let probe = min(location, text.length - 1)
        var attributes = text.attributes(at: probe, effectiveRange: nil)
        attributes.removeValue(forKey: .attachment)
        if attributes[.font] == nil { attributes[.font] = RichTextEditor.defaultFont }
        if attributes[.foregroundColor] == nil { attributes[.foregroundColor] = Palette.inkUI }
        return attributes
    }

    // MARK: Attachments — photos/doodles vs stickers
    //
    // Custom attributes don't survive the RTFD round-trip, so the two kinds are distinguished by
    // what *does* serialize: the attachment's data format + bounds. Photos and doodles are stored
    // as JPEG; stickers as PNG (they need alpha anyway) at sticker-scale bounds. Legacy entries
    // (pre-this-feature PNG photos) are caught by the bounds check — nothing sticker-sized was
    // ever inserted before stickers existed.

    enum AttachmentKind { case photo, sticker }

    static let minimizedImageWidth: CGFloat = 120
    static let stickerSides: [CGFloat] = [56, 84, 112, 140]

    static func kind(of attachment: NSTextAttachment) -> AttachmentKind {
        let isPNG: Bool = {
            guard let data = attachmentData(attachment), data.count > 1 else { return false }
            return data[data.startIndex] == 0x89 && data[data.startIndex + 1] == 0x50
        }()
        let stickerScale = max(attachment.bounds.width, attachment.bounds.height) <= DesignScale.s(150)
        return (isPNG && stickerScale) ? .sticker : .photo
    }

    static func attachmentData(_ attachment: NSTextAttachment) -> Data? {
        attachment.fileWrapper?.regularFileContents ?? attachment.contents
    }

    /// Extracts a `UIImage` regardless of whether the attachment was built in-memory or decoded
    /// from RTFD (image lives in the file wrapper).
    static func attachmentImage(_ attachment: NSTextAttachment) -> UIImage? {
        if let image = attachment.image { return image }
        return attachmentData(attachment).flatMap { UIImage(data: $0) }
    }

    /// Inserts a photo/doodle as its own full-width block (paragraph breaks before/after — no
    /// CSS-style text wrap), sized to the editor's content width. The attachment-edit bar can
    /// later flip it to the minimized thumbnail (see `toggleImageSize`).
    static func insertImage(_ image: UIImage, at location: Int, containerWidth: CGFloat,
                             in text: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: text)
        let data = image.jpegData(compressionQuality: 0.82) ?? Data()
        let attachment = NSTextAttachment(data: data, ofType: UTType.jpeg.identifier)
        let aspect = image.size.height / max(image.size.width, 1)
        attachment.bounds = CGRect(x: 0, y: 0, width: containerWidth, height: containerWidth * aspect)

        let insertion = NSMutableAttributedString(string: "\n")
        insertion.append(NSAttributedString(attachment: attachment))
        insertion.append(NSAttributedString(string: "\n", attributes: RichTextEditor.defaultAttributes))

        let safeLocation = min(max(location, 0), mutable.length)
        mutable.insert(insertion, at: safeLocation)
        return mutable
    }

    /// Inserts a sticker inline — no paragraph breaks, so it flows with the text and follows the
    /// paragraph's alignment like any other glyph.
    static func insertSticker(_ image: UIImage, at location: Int, in text: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: text)
        let data = image.pngData() ?? Data()
        let attachment = NSTextAttachment(data: data, ofType: UTType.png.identifier)
        attachment.bounds = stickerBounds(for: image, side: DesignScale.s(stickerSides[1]))
        let safeLocation = min(max(location, 0), mutable.length)
        mutable.insert(NSAttributedString(attachment: attachment), at: safeLocation)
        return mutable
    }

    private static func stickerBounds(for image: UIImage, side: CGFloat) -> CGRect {
        let aspect = image.size.height / max(image.size.width, 1)
        return aspect >= 1
            ? CGRect(x: 0, y: 0, width: side / aspect, height: side)
            : CGRect(x: 0, y: 0, width: side, height: side * aspect)
    }

    static func isFullSize(_ attachment: NSTextAttachment, containerWidth: CGFloat) -> Bool {
        attachment.bounds.width >= containerWidth - DesignScale.s(24)
    }

    /// The image's two display states: full (container width) ↔ minimized (small thumbnail that
    /// follows its paragraph's alignment, since it no longer spans the line).
    static func toggleImageSize(at index: Int, containerWidth: CGFloat,
                                 in text: NSAttributedString) -> NSAttributedString {
        guard let (attachment, image) = attachment(at: index, in: text) else { return text }
        let aspect = image.size.height / max(image.size.width, 1)
        let targetWidth = isFullSize(attachment, containerWidth: containerWidth)
            ? DesignScale.s(minimizedImageWidth)
            : containerWidth
        return replacingAttachment(at: index, in: text,
                                    bounds: CGRect(x: 0, y: 0, width: targetWidth, height: targetWidth * aspect))
    }

    /// Sticker size button: steps up through the preset sides, wrapping back to the smallest.
    static func cycleStickerSize(at index: Int, in text: NSAttributedString) -> NSAttributedString {
        guard let (attachment, image) = attachment(at: index, in: text) else { return text }
        let currentSide = max(attachment.bounds.width, attachment.bounds.height)
        let scaled = stickerSides.map { DesignScale.s($0) }
        let nextIndex = (scaled.firstIndex { $0 > currentSide + 1 } ?? 0)
        return replacingAttachment(at: index, in: text,
                                    bounds: stickerBounds(for: image, side: scaled[nextIndex]))
    }

    static func removeAttachment(at index: Int, in text: NSAttributedString) -> NSAttributedString {
        guard index < text.length,
              let attachment = text.attribute(.attachment, at: index, effectiveRange: nil) as? NSTextAttachment
        else { return text }
        let mutable = NSMutableAttributedString(attributedString: text)
        var removal = NSRange(location: index, length: 1)
        // Photos were block-inserted between newlines — take one adjacent newline with them so
        // deleting doesn't leave a stray blank line.
        if kind(of: attachment) == .photo {
            let ns = mutable.string as NSString
            if index + 1 < ns.length, ns.character(at: index + 1) == 0x0A { removal.length += 1 }
            else if index > 0, ns.character(at: index - 1) == 0x0A {
                removal = NSRange(location: index - 1, length: 2)
            }
        }
        mutable.replaceCharacters(in: removal, with: "")
        return mutable
    }

    private static func attachment(at index: Int, in text: NSAttributedString) -> (NSTextAttachment, UIImage)? {
        guard index < text.length,
              let attachment = text.attribute(.attachment, at: index, effectiveRange: nil) as? NSTextAttachment,
              let image = attachmentImage(attachment) else { return nil }
        return (attachment, image)
    }

    /// Bounds changes must go through a *fresh* attachment: mutating the existing object in place
    /// leaves the old and new `NSAttributedString` comparing equal, so the SwiftUI binding never
    /// sees the edit and the text view never relayouts.
    private static func replacingAttachment(at index: Int, in text: NSAttributedString,
                                             bounds: CGRect) -> NSAttributedString {
        guard index < text.length,
              let attachment = text.attribute(.attachment, at: index, effectiveRange: nil) as? NSTextAttachment,
              let data = attachmentData(attachment) else { return text }
        let isSticker = kind(of: attachment) == .sticker
        let fresh = NSTextAttachment(data: data,
                                     ofType: (isSticker ? UTType.png : UTType.jpeg).identifier)
        fresh.bounds = bounds
        let mutable = NSMutableAttributedString(attributedString: text)
        mutable.replaceCharacters(in: NSRange(location: index, length: 1),
                                  with: NSAttributedString(attachment: fresh))
        return mutable
    }
}

// MARK: - List kinds — plain-text prefixes ("• ", "★ ", "1. "), parsed back from paragraph text

enum ListKind: String, CaseIterable, Identifiable {
    case bullet, star, numbered
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .bullet:   return "list.bullet"
        case .star:     return "list.star"
        case .numbered: return "list.number"
        }
    }

    func prefix(number: Int = 1) -> String {
        switch self {
        case .bullet:   return "•  "
        case .star:     return "★  "
        case .numbered: return "\(max(number, 1)).  "
        }
    }

    /// Parses a paragraph's leading list prefix, if any. Returns the exact prefix text so
    /// stripping/continuation always removes precisely what's there.
    static func parseItem(_ paragraph: String) -> (kind: ListKind, prefix: String, number: Int?)? {
        if paragraph.hasPrefix(ListKind.bullet.prefix()) { return (.bullet, ListKind.bullet.prefix(), nil) }
        if paragraph.hasPrefix(ListKind.star.prefix()) { return (.star, ListKind.star.prefix(), nil) }
        let digits = paragraph.prefix(while: \.isNumber)
        if !digits.isEmpty, digits.count <= 3, Int(digits) != nil,
           paragraph.dropFirst(digits.count).hasPrefix(".  ") {
            return (.numbered, "\(digits).  ", Int(digits))
        }
        return nil
    }
}

// MARK: - Text sizes — H1/H2/H3/body presets, applied to the selection or whole paragraph

enum TextSize: String, CaseIterable, Identifiable {
    case h1, h2, h3, body
    var id: String { rawValue }

    var points: CGFloat {
        switch self {
        case .h1:   return DesignScale.s(26)
        case .h2:   return DesignScale.s(22)
        case .h3:   return DesignScale.s(19)
        case .body: return DesignScale.s(16)
        }
    }

    var label: String {
        switch self {
        case .h1:   return "H1"
        case .h2:   return "H2"
        case .h3:   return "H3"
        case .body: return "Body"
        }
    }
}

// MARK: - Curated font choices — the two bundled families plus hand-picked faces every iPhone
// ships with (addressed by PostScript name), so "lots of fonts" costs zero app size.

enum FontChoice: String, CaseIterable, Identifiable {
    case nunito = "Nunito"
    case handwritten = "Shantell Sans"
    case serif = "New York"
    case georgia = "Georgia"
    case baskerville = "Baskerville"
    case didot = "Didot"
    case typewriter = "Typewriter"
    case futura = "Futura"
    case gillSans = "Gill Sans"
    case palatino = "Palatino"
    case noteworthy = "Noteworthy"
    case bradley = "Bradley Hand"
    case marker = "Marker Felt"
    case chalkboard = "Chalkboard"
    case snell = "Snell Roundhand"
    case zapfino = "Zapfino"
    var id: String { rawValue }

    // MARK: Explicit variant names for bundled custom fonts
    // (iOS trait scanning is unreliable for non-system fonts — these give us a guaranteed lookup)

    /// PostScript name of the bold variant, if the family is a bundled custom font.
    var boldFontName: String? {
        switch self {
        case .nunito:      return "Nunito-Bold"
        case .handwritten: return "ShantellSans-Bold"
        default:           return nil
        }
    }

    /// PostScript name of the regular/base variant to return to when removing bold.
    var regularFontName: String? {
        switch self {
        case .nunito:      return "Nunito-Regular"
        case .handwritten: return "ShantellSans-Medium"
        default:           return nil
        }
    }

    /// Find the FontChoice whose base UIFont shares the given family name.
    static func matching(familyName: String) -> FontChoice? {
        allCases.first { $0.uiFont(size: 12).familyName == familyName }
    }

    func uiFont(size: CGFloat) -> UIFont {
        if self == .serif {
            let base = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            let descriptor = base.withDesign(.serif) ?? base
            return UIFont(descriptor: descriptor, size: size)
        }
        return UIFont(name: postScriptName, size: size) ?? .systemFont(ofSize: size)
    }

    private var postScriptName: String {
        switch self {
        case .nunito:      return "Nunito-Regular"
        case .handwritten: return "ShantellSans-Medium"
        case .serif:       return ""
        case .georgia:     return "Georgia"
        case .baskerville: return "Baskerville"
        case .didot:       return "Didot"
        case .typewriter:  return "AmericanTypewriter"
        case .futura:      return "Futura-Medium"
        case .gillSans:    return "GillSans"
        case .palatino:    return "Palatino-Roman"
        case .noteworthy:  return "Noteworthy-Light"
        case .bradley:     return "BradleyHandITCTT-Bold"
        case .marker:      return "MarkerFelt-Thin"
        case .chalkboard:  return "ChalkboardSE-Regular"
        case .snell:       return "SnellRoundhand-Bold"
        case .zapfino:     return "Zapfino"
        }
    }
}

// MARK: - Plain-text bridge — attachments render as U+FFFC in `.string`; strip them anywhere the
// text is *text* (word counts, `content` storage, row snippets) so a photo never counts as a word
// or renders as a placeholder box.

extension NSAttributedString {
    var plainText: String { string.replacingOccurrences(of: "\u{FFFC}", with: "") }

    /// Small JPEG of the first photo/doodle attachment (stickers skipped) — the History row
    /// thumbnail, generated once at save so rows never decode RTFD.
    func firstPhotoThumbnail(maxDimension: CGFloat = 320) -> Data? {
        var found: UIImage?
        enumerateAttribute(.attachment, in: NSRange(location: 0, length: length), options: []) { value, _, stop in
            guard let attachment = value as? NSTextAttachment,
                  RichTextFormatting.kind(of: attachment) == .photo,
                  let image = RichTextFormatting.attachmentImage(attachment) else { return }
            found = image
            stop.pointee = true
        }
        return found?
            .downscaledForJournal(maxDimension: maxDimension, quality: 0.7)
            .jpegData(compressionQuality: 0.7)
    }
}

// MARK: - Image downscaling — keeps `richContent` reasonably sized once a photo is embedded in
// the RTFD blob, and avoids inserting multi-MB camera originals into the editor.

extension UIImage {
    func downscaledForJournal(maxDimension: CGFloat = 1600, quality: CGFloat = 0.8) -> UIImage {
        let largestSide = max(size.width, size.height)
        let scale = largestSide > maxDimension ? maxDimension / largestSide : 1
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
        guard let data = resized.jpegData(compressionQuality: quality), let recompressed = UIImage(data: data) else {
            return resized
        }
        return recompressed
    }
}

// MARK: - Font variant availability — some iOS faces (Zapfino, Snell Roundhand, Marker Felt,
// Bradley Hand…) ship with only one weight/style and have no bold or italic sibling registered
// in the system font database. `withSymbolicTraits` returns nil in those cases, meaning bold/italic
// commands silently do nothing. Checking via the family's registered names is more reliable than
// probing withSymbolicTraits on the descriptor alone.

extension UIFont {
    /// True if the font's family has at least one registered variant carrying `trait`.
    func supports(_ trait: UIFontDescriptor.SymbolicTraits) -> Bool {
        let family = fontDescriptor.object(forKey: .family) as? String ?? familyName
        return UIFont.fontNames(forFamilyName: family).contains { name in
            UIFontDescriptor(name: name, size: pointSize).symbolicTraits.contains(trait)
        }
    }

    /// Returns a variant of this font with `trait` added. Tries descriptor synthesis first (works
    /// for system fonts); falls back to scanning the font family for a registered member that
    /// carries the trait (needed for custom fonts loaded by PostScript name like Nunito-SemiBold).
    func addingTrait(_ trait: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        let newTraits = fontDescriptor.symbolicTraits.union(trait)
        if let desc = fontDescriptor.withSymbolicTraits(newTraits) {
            return UIFont(descriptor: desc, size: pointSize)
        }
        // Fallback 1: find a family member that has the trait via OS registration
        let family = fontDescriptor.object(forKey: .family) as? String ?? familyName
        for name in UIFont.fontNames(forFamilyName: family) {
            let desc = UIFontDescriptor(name: name, size: pointSize)
            if desc.symbolicTraits.contains(trait) {
                return UIFont(descriptor: desc, size: pointSize)
            }
        }
        // Fallback 2: explicit PostScript name for bundled custom fonts whose metadata
        // doesn't advertise traits reliably (Nunito, Shantell Sans, etc.)
        if trait.contains(.traitBold),
           let choice = FontChoice.matching(familyName: family),
           let boldName = choice.boldFontName,
           let f = UIFont(name: boldName, size: pointSize) {
            return f
        }
        return nil
    }

    /// Returns a variant of this font with `trait` removed — the most neutral (fewest traits)
    /// family member that doesn't carry the trait.
    func removingTrait(_ trait: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        let newTraits = fontDescriptor.symbolicTraits.subtracting(trait)
        if let desc = fontDescriptor.withSymbolicTraits(newTraits) {
            return UIFont(descriptor: desc, size: pointSize)
        }
        let family = fontDescriptor.object(forKey: .family) as? String ?? familyName
        let candidates = UIFont.fontNames(forFamilyName: family).filter { name in
            !UIFontDescriptor(name: name, size: pointSize).symbolicTraits.contains(trait)
        }
        // Pick the member with the fewest symbolic traits (closest to "plain")
        let best = candidates.min { a, b in
            UIFontDescriptor(name: a, size: pointSize).symbolicTraits.rawValue.nonzeroBitCount
            < UIFontDescriptor(name: b, size: pointSize).symbolicTraits.rawValue.nonzeroBitCount
        }
        if let found = best {
            return UIFont(descriptor: UIFontDescriptor(name: found, size: pointSize), size: pointSize)
        }
        // Fallback: explicit regular/base PostScript name for bundled custom fonts
        if trait.contains(.traitBold),
           let choice = FontChoice.matching(familyName: family),
           let regName = choice.regularFontName,
           let f = UIFont(name: regName, size: pointSize) {
            return f
        }
        return nil
    }
}

// MARK: - Photo picker with crop — deliberately `UIImagePickerController`, not the modern
// `PhotosPicker`. `PhotosPicker`/`PHPickerViewController` run out-of-process and have no crop
// step at all; `UIImagePickerController` with `allowsEditing` gives Apple's standard crop/zoom
// screen (the same one Messages/Photos use) right after picking, at the cost of running
// in-process (hence the `NSPhotoLibraryUsageDescription` this needs in Info.plist, which
// `PhotosPicker` never required).
struct ImagePickerWithCrop: UIViewControllerRepresentable {
    var onImagePicked: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerWithCrop
        init(_ parent: ImagePickerWithCrop) { self.parent = parent }

        // Dismissal is left entirely to the `.sheet(isPresented:)` binding in RitualView (via
        // `onImagePicked`/`onCancel` below) — calling `picker.dismiss()` here too, on top of that
        // SwiftUI-driven dismissal, is what caused the picker to loop (present/dismiss fighting
        // itself between the imperative UIKit call and the declarative SwiftUI one).
        func imagePickerController(_ picker: UIImagePickerController,
                                    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            if let image { parent.onImagePicked(image) }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}
