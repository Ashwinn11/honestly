import SwiftUI
import UIKit

enum Brand: String, CaseIterable, Identifiable {
    case instagram, tiktok, youtube, snapchat, x, whatsapp
    var id: String { rawValue }
    var assetName: String { "brand-\(rawValue)" }
    var hasAsset: Bool { UIImage(named: assetName) != nil }
}

struct BrandIcon: View {
    let brand: Brand
    var size: CGFloat = 58

    var body: some View {
        Group {
            if brand.hasAsset {
                Image(brand.assetName).resizable().scaledToFill()
            } else {
                ZStack { background; glyph }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
    }

    @ViewBuilder private var background: some View {
        switch brand {
        case .instagram:
            LinearGradient(colors: [Color(hex: "FEDA75"), Color(hex: "FA7E1E"), Color(hex: "D62976"),
                                    Color(hex: "962FBF"), Color(hex: "4F5BD5")],
                           startPoint: .bottomLeading, endPoint: .topTrailing)
        case .tiktok:   Color(hex: "010101")
        case .youtube:  Color(hex: "FF0000")
        case .snapchat: Color(hex: "FFFC00")
        case .x:        Color(hex: "050505")
        case .whatsapp: Color(hex: "25D366")
        }
    }

    @ViewBuilder private var glyph: some View {
        switch brand {
        case .instagram:
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                    .stroke(.white, lineWidth: size * 0.075).frame(width: size * 0.56, height: size * 0.56)
                Circle().stroke(.white, lineWidth: size * 0.075).frame(width: size * 0.27, height: size * 0.27)
                Circle().fill(.white).frame(width: size * 0.08, height: size * 0.08)
                    .offset(x: size * 0.17, y: -size * 0.17)
            }
        case .tiktok:
            ZStack {
                note(color: Color(hex: "FE2C55")).offset(x: -size * 0.03, y: size * 0.02)
                note(color: Color(hex: "25F4EE")).offset(x: size * 0.03, y: -size * 0.02)
                note(color: .white)
            }
        case .youtube:
            Triangle().fill(.white).frame(width: size * 0.26, height: size * 0.3)
                .offset(x: size * 0.02)
        case .snapchat:
            Ghost().fill(.white).frame(width: size * 0.5, height: size * 0.56)
        case .x:
            ZStack {
                Capsule().fill(.white).frame(width: size * 0.5, height: size * 0.1).rotationEffect(.degrees(45))
                Capsule().fill(.white).frame(width: size * 0.5, height: size * 0.1).rotationEffect(.degrees(-45))
            }
        case .whatsapp:
            ZStack {
                WhatsAppBubble().fill(.white).frame(width: size * 0.66, height: size * 0.66)
                Image(systemName: "phone.fill").font(.system(size: size * 0.26))
                    .foregroundColor(Color(hex: "25D366")).offset(y: -size * 0.02)
            }
        }
    }

    private func note(color: Color) -> some View {
        Image(systemName: "music.note").font(.system(size: size * 0.5, weight: .medium)).foregroundStyle(color)
    }
}

private struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

private struct Ghost: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        let base = r.minY + h * 0.82
        p.move(to: CGPoint(x: r.minX + w * 0.12, y: base))
        p.addLine(to: CGPoint(x: r.minX + w * 0.12, y: r.minY + h * 0.42))
        p.addArc(center: CGPoint(x: r.midX, y: r.minY + h * 0.42),
                 radius: w * 0.38, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: r.maxX - w * 0.12, y: base))
        let bumps = 3
        let bw = (w * 0.76) / CGFloat(bumps)
        for i in 0..<bumps {
            let cx = r.maxX - w * 0.12 - bw * CGFloat(i) - bw / 2
            p.addArc(center: CGPoint(x: cx, y: base), radius: bw / 2,
                     startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        }
        p.closeSubpath()
        return p
    }
}

private struct WhatsAppBubble: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let d = min(r.width, r.height)
        p.addEllipse(in: CGRect(x: r.minX, y: r.minY, width: d, height: d * 0.92))
        p.move(to: CGPoint(x: r.minX + d * 0.30, y: r.minY + d * 0.78))
        p.addLine(to: CGPoint(x: r.minX + d * 0.02, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + d * 0.42, y: r.minY + d * 0.86))
        p.closeSubpath()
        return p
    }
}

