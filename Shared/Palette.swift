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
    static let hairline    = Color(hex: "D8CBB6")   // chevrons / faint rules

    /// Standard black-ink card outlines from the redesign.
    static let outline     = ink                            // 2px solid emphasis
    static let outlineSoft = ink.opacity(0.2)               // 1.5px default card border
    static let iconTile    = Color(hex: "FFF1DC")           // cream-amber icon container fill
    static let onAmber     = Color(hex: "FFF7EA")           // cream button sitting on an amber card

    // MARK: Sunrise accent
    static let amber       = Color(hex: "F5851F")   // primary / accent
    static let amberDeep   = Color(hex: "BC5E17")   // text-on-amber-card / links
    static let sunDisc     = Color(hex: "F7B23C")   // the sun's gold disc / Happy-adjacent gold

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

    // MARK: Supporting tones — every colour a screen uses lives here, never as a hex in a view
    static let warmShadow  = Color(hex: "78501E")   // the brown in every card and book shadow
    static let pressedRow  = Color(hex: "FAF5EE")   // a settings row while pressed
    static let selectedFill = Color(hex: "FFF6E7")  // a chosen plan / option card
    static let notifBody   = Color(hex: "5A4A38")   // body text in a notification preview
    static let sunTint     = Color(hex: "FFF4E0")   // a sun drawn on a coral card
    static let sectionLabel = Color(hex: "A0917C")  // month labels over search results
    static let eyebrowSoft = Color(hex: "C0B29A")   // section eyebrows in Profile
    static let emptyTrack  = Color(hex: "F2EADB")   // an empty bar (no moods yet)
    static let glyphGold   = Color(hex: "F6C33F")   // sparkles and stars in illustrations
    static let glyphBlush  = Color(hex: "F19DA6")   // hearts in illustrations
    static let leather     = Color(hex: "4A3626")   // the book's frame when its cover is a photo
    static let leatherInk  = Color(hex: "FFF7EA")   // text on leather
    static let highlighter = Color(hex: "FFE89A")   // the text highlighter
    static let tear        = Color(hex: "5B8FD6")   // the crying face's tears
    static let leafShadow  = Color(hex: "3C5A28")   // shadow under the green "done" card
    static let emberShadow = Color(hex: "78280A")   // glow under text on the celebration gradient

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
    static let sunDiscUI  = UIColor(hex: "F7B23C")
}

enum Mood: Int, CaseIterable, Identifiable, Codable {
    case happy = 0, confused, sad, awful, cry
    var id: Int { rawValue }
    var label: String    { ["Happy", "Confused", "Sad", "Awful", "Cry"][rawValue] }
}
