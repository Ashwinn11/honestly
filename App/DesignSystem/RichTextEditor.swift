import SwiftUI
import UIKit

/// A `UITextView` bridge for rich formatting (bold/italic/underline/font/color/highlight) plus
/// inline images — SwiftUI's own `TextEditor` has no attributed-text support at this app's iOS 18
/// minimum, but `UITextView`/`NSAttributedString` have supported all of this natively for years.
struct RichTextEditor: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var isEditingAllowed: Bool          // premium.isPremium — locks rich formatting at the UIKit level
    @Binding var selectedRange: NSRange
    var placeholder: String = ""

    static let defaultFont: UIFont =
        UIFont(name: "Nunito-SemiBold", size: DesignScale.s(16)) ?? .systemFont(ofSize: DesignScale.s(16))
    static var defaultAttributes: [NSAttributedString.Key: Any] {
        [.font: defaultFont, .foregroundColor: Palette.inkUI]
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
        guard uiView.attributedText != attributedText else { return }
        let selection = uiView.selectedRange
        uiView.attributedText = attributedText
        let len = (uiView.text as NSString).length
        let clampedLocation = min(selection.location, len)
        let clampedLength = min(selection.length, max(0, len - clampedLocation))
        uiView.selectedRange = NSRange(location: clampedLocation, length: clampedLength)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        var isApplyingSwiftUIUpdate = false
        weak var placeholderLabel: UILabel?
        init(_ parent: RichTextEditor) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            placeholderLabel?.isHidden = !(textView.text ?? "").isEmpty
            guard !isApplyingSwiftUIUpdate else { return }
            let attributedText = NSAttributedString(attributedString: textView.attributedText ?? NSAttributedString())
            guard parent.attributedText != attributedText else { return }
            parent.attributedText = attributedText
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isApplyingSwiftUIUpdate else { return }
            let selectedRange = textView.selectedRange
            guard parent.selectedRange != selectedRange else { return }
            parent.selectedRange = selectedRange
        }
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
        let currentFont = (text.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont)
            ?? RichTextEditor.defaultFont
        let turningOn = !currentFont.fontDescriptor.symbolicTraits.contains(trait)
        mutable.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
            let font = (value as? UIFont) ?? RichTextEditor.defaultFont
            var traits = font.fontDescriptor.symbolicTraits
            if turningOn { traits.insert(trait) } else { traits.remove(trait) }
            if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                mutable.addAttribute(.font, value: UIFont(descriptor: descriptor, size: font.pointSize), range: subrange)
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

    static func setHighlight(_ color: UIColor?, in text: NSAttributedString, range: NSRange) -> NSAttributedString {
        guard range.length > 0 else { return text }
        let mutable = NSMutableAttributedString(attributedString: text)
        if let color {
            mutable.addAttribute(.backgroundColor, value: color, range: range)
        } else {
            mutable.removeAttribute(.backgroundColor, range: range)
        }
        return mutable
    }

    static func setFont(_ choice: FontChoice, in text: NSAttributedString, range: NSRange) -> NSAttributedString {
        guard range.length > 0 else { return text }
        let mutable = NSMutableAttributedString(attributedString: text)
        mutable.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
            let size = (value as? UIFont)?.pointSize ?? RichTextEditor.defaultFont.pointSize
            mutable.addAttribute(.font, value: choice.uiFont(size: size), range: subrange)
        }
        return mutable
    }

    /// Inserts an image as its own full-width block (paragraph breaks before/after — no
    /// CSS-style text wrap), sized to the editor's content width.
    static func insertImage(_ image: UIImage, at location: Int, containerWidth: CGFloat,
                             in text: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: text)
        let attachment = NSTextAttachment()
        attachment.image = image
        let aspect = image.size.height / max(image.size.width, 1)
        attachment.bounds = CGRect(x: 0, y: 0, width: containerWidth, height: containerWidth * aspect)

        let insertion = NSMutableAttributedString(string: "\n")
        insertion.append(NSAttributedString(attachment: attachment))
        insertion.append(NSAttributedString(string: "\n", attributes: RichTextEditor.defaultAttributes))

        let safeLocation = min(max(location, 0), mutable.length)
        mutable.insert(insertion, at: safeLocation)
        return mutable
    }
}

// MARK: - Curated font choices — the app only bundles Nunito + Shantell Sans, so an open system
// font picker would offer weights nothing else in the app uses; a serif option uses the system's
// own New York design instead of a hand-picked bundled font.

enum FontChoice: String, CaseIterable, Identifiable {
    case nunito = "Nunito"
    case handwritten = "Shantell Sans"
    case serif = "Serif"
    var id: String { rawValue }

    func uiFont(size: CGFloat) -> UIFont {
        switch self {
        case .nunito:
            return UIFont(name: "Nunito-SemiBold", size: size) ?? .systemFont(ofSize: size)
        case .handwritten:
            return UIFont(name: "ShantellSans-SemiBold", size: size) ?? .systemFont(ofSize: size)
        case .serif:
            let base = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            let descriptor = base.withDesign(.serif) ?? base
            return UIFont(descriptor: descriptor, size: size)
        }
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
