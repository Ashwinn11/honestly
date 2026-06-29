import SwiftUI

// Potted-plant character that grows by stage. Art comes from the sliced
// illustrations in Assets.xcassets (plant-seedling … plant-bloom).
// Public API PlantView(stage:size:) is kept stable for all call sites.

struct PlantView: View {
    var stage: PlantStage = .sprout
    var size: CGFloat = 80
    /// Retained for call-site compatibility; the illustrated pots have no drawn face.
    var showFace: Bool = true

    var body: some View {
        Image("plant-\(stage.assetKey)")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
