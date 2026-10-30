import SwiftUI

/// Sticker sheet — curated OpenMoji artwork (hand-drawn outline style, which sits naturally next
/// to this app's ink-and-paper look), bundled in `Assets.xcassets/Stickers` as `om<hexcode>`
/// imagesets. Picking one hands the editor a `UIImage` to insert inline at the caret.
///
/// OpenMoji is CC BY-SA 4.0 — attribution lives here in the sheet footer and in Profile.
struct StickerPicker: View {
    var onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(PremiumManager.self) private var premium
    @State private var categoryIndex = 0
    @State private var showPaywall = false

    private static let categories: [StickerCategory] = [
        .init(label: "Moods", icon: "face.smiling",
              codes: ["1F600", "1F604", "1F970", "1F60A", "1F929", "1F60E",
                      "1F972", "1F614", "1F622", "1F62D", "1F621", "1F634"]),
        .init(label: "Hearts", icon: "heart",
              codes: ["2764", "1F9E1", "1F49B", "1F49A", "1F499", "1F49C",
                      "1F90E", "1F494", "1F495", "1F496", "1F497", "1F498"]),
        .init(label: "Nature", icon: "leaf",
              codes: ["1F338", "1F33B", "1F337", "1F339", "1F340", "1F341",
                      "1F33F", "1F334", "1F98B", "1F41D", "1F31E", "1F343"]),
        .init(label: "Food", icon: "cup.and.saucer",
              codes: ["2615", "1F375", "1F9C1", "1F370", "1F355", "1F353",
                      "1F34A", "1F951", "1F36A", "1F366", "1F963", "1F35C"]),
        .init(label: "Party", icon: "party.popper",
              codes: ["1F389", "1F38A", "1F388", "1F381", "1F382", "2728",
                      "1F31F", "1F386", "1F387", "1F3C6", "1F947", "1F4AB"]),
        .init(label: "Weather", icon: "sun.max",
              codes: ["2600", "26C5", "2601", "1F327", "26C8", "1F308",
                      "2744", "1F319", "2B50", "26A1", "1F324", "1F30A"]),
    ]

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(Text(loc: "Stickers"), trailing: {
                IconTileButton.close { dismiss() }
            })
            .padding(EdgeInsets(top: 18, leading: 20, bottom: 10, trailing: 20))

            categoryRow

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Self.categories[categoryIndex].codes, id: \.self) { code in
                        Button {
                            if categoryLocked {
                                showPaywall = true
                                return
                            }
                            guard let image = UIImage(named: "om\(code)") else { return }
                            Haptics.select()
                            onPick(image)
                            dismiss()
                        } label: {
                            Image("om\(code)")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 56, height: 56)
                                .padding(6)
                                .overlay(alignment: .topTrailing) {
                                    if categoryLocked { PremiumLockBadge() }
                                }
                        }
                        .accessibilityIdentifier("sticker.\(code)")
                        .buttonStyle(PressableStyle(scale: 0.85))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Text("Stickers: OpenMoji.org · CC BY-SA 4.0")
                    .font(Fonts.ui(10.5, .semibold)).foregroundStyle(Palette.inkSofter)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
            }
        }
        .sheetBackground()
        .paywallCover(isPresented: $showPaywall)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    /// Browsing a locked category is free; each of its stickers carries the lock.
    private var categoryRow: some View {
        ChipTabs(items: Array(Self.categories.indices), selection: $categoryIndex,
                 title: { Self.categories[$0].label }, icon: { Self.categories[$0].icon })
    }

    /// The first pack ("Moods") is free; the rest need Premium.
    private var categoryLocked: Bool {
        categoryIndex >= PremiumFeature.freeStickerPacks && !premium.allows(.allStickers)
    }

}

private struct StickerCategory {
    let label: String
    let icon: String
    let codes: [String]
}
