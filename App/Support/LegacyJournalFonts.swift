import Foundation

/// Rewrite only the RTF font table, before UIKit substitutes unavailable fonts.
/// Journal text, font indices, sizes, formatting commands and attachment data stay intact.
enum LegacyJournalFonts {
    static func remapFontTable(in data: Data) -> Data {
        let bytes = [UInt8](data)
        let marker = Array("{\\fonttbl".utf8)
        guard let start = bytes.indices.first(where: {
            $0 + marker.count <= bytes.count && bytes[$0..<($0 + marker.count)].elementsEqual(marker)
        }) else { return data }
        var depth = 0
        var cursor = start
        var end: Int?
        while cursor < bytes.count {
            let byte = bytes[cursor]
            if byte == 92 { cursor += 2; continue } // Escaped braces aren't group boundaries.
            if byte == 123 { depth += 1 }
            if byte == 125 {
                depth -= 1
                if depth == 0 { end = cursor + 1; break }
            }
            cursor += 1
        }
        guard let end,
              var table = String(data: Data(bytes[start..<end]), encoding: .isoLatin1) else { return data }
        let pattern = #"(?:Nunito|Shantell(?:Sans| Sans))(?:[- ](?:ExtraBold|SemiBold|Regular|Medium|Bold|Black))?(?=\s*[;}])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return data }
        let matches = regex.matches(in: table, range: NSRange(table.startIndex..., in: table))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: table) else { continue }
            let name = String(table[range])
            let bold = name.contains("Bold") || name.contains("Black")
            let replacement = name.hasPrefix("Nunito")
                ? (bold ? "Manrope-Bold" : "Manrope-Regular")
                : (bold ? "ChalkboardSE-Bold" : "ChalkboardSE-Regular")
            table.replaceSubrange(range, with: replacement)
        }
        guard !matches.isEmpty, let mapped = table.data(using: .isoLatin1) else { return data }
        return Data(bytes[..<start]) + mapped + Data(bytes[end...])
    }
}
