import SwiftUI
import UIKit

enum Palette {

    // MARK: Core surfaces & ink
    static let paper       = Color(hex: "FAF8F5")   // warm unbleached paper — screen background
    static let cream       = Color(hex: "FFFDF8")   // card surface (hand-drawn warmth)
    static let ink         = Color(hex: "33261A")   // espresso — primary text / the ink outline
    static let inkBody      = Color(hex: "4A3B2C")  // long-form body copy
    static let inkSoft     = Color(hex: "8A7A67")   // secondary text
    static let inkSofter   = Color(hex: "B7A991")   // tertiary / hints
    static let inkMuted    = Color(hex: "C3B6A2")   // placeholder / faint
    static let eyebrow     = Color(hex: "C0B29A")   // uppercase eyebrow labels
    static let hairline    = Color(hex: "D8CBB6")   // chevrons / faint rules
    static let dashFuture  = Color(hex: "DACDB8")   // future/empty day numerals

    /// Standard black-ink card outlines from the redesign.
    static let outline     = ink                            // 2px solid emphasis
    static let outlineSoft = ink.opacity(0.2)               // 1.5px default card border
    static let iconTile    = Color(hex: "FFF1DC")           // cream-amber icon container fill
    static let onAmber     = Color(hex: "FFF7EA")           // cream button sitting on an amber card

    // MARK: Sunrise accent
    static let amber       = Color(hex: "F5851F")   // primary / accent
    static let amberLight  = Color(hex: "FF9A4D")   // secondary glow
    static let amberDeep   = Color(hex: "BC5E17")   // text-on-amber-card / links
    static let sunDisc     = Color(hex: "F7B23C")   // the sun's gold disc / Happy-adjacent gold
    static let amberGradient = LinearGradient(colors: [amber, amberLight],
                                              startPoint: .topLeading, endPoint: .bottomTrailing)

    // Warm hero gradient (home "this morning" card, celebration)
    static let heroWarm    = Color(hex: "FF9E42")
    static let heroDeep    = Color(hex: "F0611A")
    static let heroDeepest = Color(hex: "E4551A")
    static let heroGradient = LinearGradient(colors: [heroWarm, heroDeep],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
    static let celebrationGradient = LinearGradient(colors: [heroWarm, heroDeep, heroDeepest],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing)

    // MARK: Semantic
    static let success     = Color(hex: "5B9A6B")   // "On" / "Goal met"
    static let danger      = Color(hex: "D3574A")   // destructive

    // MARK: Moods — index 0…4 = Happy · Confused · Sad · Awful · Cry
    static let moods: [Color]    = ["F7C24B", "A8CB8C", "90B4DC", "C79ACD", "6E9BD6"].map { Color(hex: $0) }
    static let moodSoft: [Color] = ["FCEFCB", "E9F1DF", "E1EAF6", "EFE2F1", "DDE8F5"].map { Color(hex: $0) }
    static func mood(_ i: Int) -> Color     { moods[min(max(i, 0), 4)] }
    static func moodSoft(_ i: Int) -> Color { moodSoft[min(max(i, 0), 4)] }

    // Eyes / mouths, drawn in ink over the mood disc.
    static let moodInk: [Color] = ["5A3D12", "33471F", "22344D", "4E3357", "22406B"].map { Color(hex: $0) }
    static func moodInk(_ i: Int) -> Color  { moodInk[min(max(i, 0), 4)] }

    // MARK: UIKit mirror (shield extension is UIKit)
    static let paperUI    = UIColor(hex: "FAF8F5")
    static let inkUI      = UIColor(hex: "33261A")
    static let inkSoftUI  = UIColor(hex: "8A7A67")
    static let amberUI    = UIColor(hex: "F5851F")
}

enum Mood: Int, CaseIterable, Identifiable, Codable {
    case happy = 0, confused, sad, awful, cry
    var id: Int { rawValue }
    var color: Color     { Palette.mood(rawValue) }
    var soft: Color      { Palette.moodSoft(rawValue) }
    var ink: Color       { Palette.moodInk(rawValue) }
    var label: String    { ["Happy", "Confused", "Sad", "Awful", "Cry"][rawValue] }
}
