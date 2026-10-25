import SwiftUI

enum Brand: String {
    case instagram, tiktok, snapchat

    var assetName: String { "brand-\(rawValue)" }
}

struct BrandIcon: View {
    let brand: Brand
    var size: CGFloat = 58

    var body: some View {
        Image(brand.assetName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
    }
}
