import Foundation

enum PlantStage: Int, CaseIterable, Identifiable {
    case sprout = 0
    case young  = 1
    case leafy  = 2
    case lush   = 3
    case bloom  = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .sprout: return "sprout"
        case .young:  return "young"
        case .leafy:  return "leafy"
        case .lush:   return "lush"
        case .bloom:  return "bloom"
        }
    }

    /// Localized name for display. `displayName` stays English so `assetKey`
    /// keeps resolving to the on-disk asset.
    var localizedName: String { L(displayName) }

    /// Asset name in Assets.xcassets (plant-<key>).
    var assetKey: String { displayName }

    var range: String {
        switch self {
        case .sprout: return "0 – 9"
        case .young:  return "10 – 29"
        case .leafy:  return "30 – 89"
        case .lush:   return "90 – 179"
        case .bloom:  return "180+"
        }
    }

    /// Short description shown on the "your garden stages" sheet.
    var blurb: String {
        switch self {
        case .sprout: return L("A few fresh leaves to start.")
        case .young:  return L("Filling out, finding the light.")
        case .leafy:  return L("Bushy and green all over.")
        case .lush:   return L("Full, healthy, thriving.")
        case .bloom:  return L("Flourishing — the milestone reward.")
        }
    }

    var threshold: Int { AppConstants.plantStageThresholds[rawValue] }

    static func stage(for sproutCount: Int) -> PlantStage {
        PlantStage(rawValue: AppConstants.stageForCount(sproutCount)) ?? .sprout
    }
}
