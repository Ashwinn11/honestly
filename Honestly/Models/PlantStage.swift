import Foundation

enum PlantStage: Int, CaseIterable, Identifiable {
    case sprout    = 0
    case young     = 1
    case mature    = 2
    case flowering = 3

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .sprout:    return "sprout"
        case .young:     return "young"
        case .mature:    return "mature"
        case .flowering: return "flowering"
        }
    }

    var range: String {
        switch self {
        case .sprout:    return "0 – 29"
        case .young:     return "30 – 89"
        case .mature:    return "90 – 179"
        case .flowering: return "180+"
        }
    }

    /// Short description shown on the "your garden stages" sheet.
    var blurb: String {
        switch self {
        case .sprout:    return "Day one. a single seedling."
        case .young:     return "Stems up, real leaves unfurl."
        case .mature:    return "Full, bushy foliage."
        case .flowering: return "It blooms — the milestone reward."
        }
    }

    var threshold: Int { AppConstants.plantStageThresholds[rawValue] }

    static func stage(for sproutCount: Int) -> PlantStage {
        PlantStage(rawValue: AppConstants.stageForCount(sproutCount)) ?? .sprout
    }
}
