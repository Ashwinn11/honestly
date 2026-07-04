import SwiftUI
import UIKit

enum Palette {

    // MARK: Core surfaces & ink
    static let paper       = Color(hex: "FAF8F5")   // warm unbleached paper — screen background
    static let ink         = Color(hex: "33261A")   // espresso — primary text
    static let inkBody      = Color(hex: "4A3B2C")  // long-form body copy
    static let inkSoft     = Color(hex: "8A7A67")   // secondary text
    static let inkSofter   = Color(hex: "B7A991")   // tertiary / hints
    static let inkMuted    = Color(hex: "C3B6A2")   // placeholder / faint
    static let eyebrow     = Color(hex: "C0B29A")   // uppercase eyebrow labels
    static let hairline    = Color(hex: "D8CBB6")   // chevrons / faint rules
    static let dashFuture  = Color(hex: "DACDB8")   // future/empty day numerals

    // MARK: Sunrise accent
    static let amber       = Color(hex: "FA691E")   // primary / accent / Happy
    static let amberLight  = Color(hex: "FF9A4D")   // gradient top / glow
    static let amberDeep   = Color(hex: "C85311")   // text-on-amber-card
    static let amberGradient = LinearGradient(colors: [amber, amberLight],
                                              startPoint: .topLeading, endPoint: .bottomTrailing)

    // MARK: Semantic
    static let success     = Color(hex: "22A06B")
    static let danger      = Color(hex: "E5484D")

    // MARK: Moods — index 0…4 = Happy · Confused · Sad · Awful · Cry
    static let moods: [Color]    = ["FA691E", "B4CE98", "F2A39B", "E57380", "A7CBEA"].map { Color(hex: $0) }
    static let moodSoft: [Color] = ["FCE3D2", "E9F1DF", "FCE6E3", "F9DEE2", "E4EEF8"].map { Color(hex: $0) }
    static func mood(_ i: Int) -> Color     { moods[min(max(i, 0), 4)] }
    static func moodSoft(_ i: Int) -> Color { moodSoft[min(max(i, 0), 4)] }

    static let moodInk: [Color] = ["7A2A0C", "3E5B2A", "8A3A34", "5C120D", "26295C"].map { Color(hex: $0) }
    static func moodInk(_ i: Int) -> Color  { moodInk[min(max(i, 0), 4)] }

    // MARK: UIKit mirror (shield extension is UIKit)
    static let paperUI    = UIColor(hex: "FAF8F5")
    static let inkUI      = UIColor(hex: "33261A")
    static let inkSoftUI  = UIColor(hex: "8A7A67")
    static let amberUI    = UIColor(hex: "FA691E")
}

enum Mood: Int, CaseIterable, Identifiable, Codable {
    case happy = 0, confused, sad, awful, cry
    var id: Int { rawValue }
    var color: Color     { Palette.mood(rawValue) }
    var soft: Color      { Palette.moodSoft(rawValue) }
    var ink: Color       { Palette.moodInk(rawValue) }
    var label: String    { ["Happy", "Confused", "Sad", "Awful", "Cry"][rawValue] }
}
