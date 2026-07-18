import SwiftUI
import UIKit

/// Renders a formatted `NSAttributedString` (with inline images) read-only, in SwiftUI.
///
/// Does **not** use the automatic `Text(AttributedString(nsAttributedString:))` bridge — that
/// bridge is confirmed to drop `NSTextAttachment` images entirely, and `.backgroundColor`
/// (highlight) rendering through it is unreliable. Instead this walks the `NSAttributedString`
/// directly and builds each `SwiftUI.AttributedString` run attribute-by-attribute, so every
/// attribute the editor's toolbar can produce is deliberately, individually mapped.
struct RichContentRenderer: View {
    let attributedText: NSAttributedString

    private enum Block: Identifiable {
        case text(AttributedString)
        case image(UIImage)
        var id: String {
            switch self {
            case .text(let s): return "t-\(s.description.hashValue)"
            case .image(let i): return "i-\(ObjectIdentifier(i).hashValue)"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let s):
                    Text(s).fixedSize(horizontal: false, vertical: true)
                case .image(let img):
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private var blocks: [Block] {
        var result: [Block] = []
        let full = NSRange(location: 0, length: attributedText.length)
        var textRun = AttributedString()

        attributedText.enumerateAttributes(in: full, options: []) { attrs, range, _ in
            if let attachment = attrs[.attachment] as? NSTextAttachment,
               let image = Self.image(from: attachment) {
                if !textRun.characters.isEmpty {
                    result.append(.text(textRun))
                    textRun = AttributedString()
                }
                result.append(.image(image))
                return
            }
            let substring = attributedText.attributedSubstring(from: range).string
            guard substring != "\u{FFFC}" else { return }   // the attachment's own placeholder char

            var run = AttributedString(substring)
            if let font = attrs[.font] as? UIFont {
                run.font = Font(font)
            }
            if let color = attrs[.foregroundColor] as? UIColor {
                run.foregroundColor = Color(color)
            } else {
                run.foregroundColor = Palette.inkBody
            }
            if let bg = attrs[.backgroundColor] as? UIColor {
                run.backgroundColor = Color(bg)
            }
            if let underline = attrs[.underlineStyle] as? Int, underline != 0 {
                run.underlineStyle = .single
            }
            textRun += run
        }
        if !textRun.characters.isEmpty {
            result.append(.text(textRun))
        }
        return result
    }

    /// Extracts a `UIImage` from an `NSTextAttachment` regardless of whether the attachment was
    /// built in-memory (`.image` is set) or decoded from RTFD (image lives in the file wrapper).
    private static func image(from attachment: NSTextAttachment) -> UIImage? {
        if let img = attachment.image { return img }
        if let data = attachment.fileWrapper?.regularFileContents { return UIImage(data: data) }
        if let data = attachment.contents { return UIImage(data: data) }
        return nil
    }
}
