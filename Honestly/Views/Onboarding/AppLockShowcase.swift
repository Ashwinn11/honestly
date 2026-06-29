import SwiftUI

// Animated demo for the app-blocking onboarding slide: social-app tiles start
// locked (dimmed + lock badge, like iOS Screen Time), then the locks pop off and
// the icons brighten — looping. Ported from PrayerLock's AppLockShowcase, adapted
// to Honestly's Theme tokens and String-based Color(hex:).

struct AppLockShowcase: View {
    @State private var locked = true
    var tile: CGFloat = 60
    private let timer = Timer.publish(every: 2.4, on: .main, in: .common).autoconnect()
    private let brands: [AppBrand] = [.instagram, .snapchat, .x, .whatsapp]

    var body: some View {
        HStack(spacing: AppLayout.s(16)) {
            ForEach(brands) { brand in
                AppIconTile(brand: brand, locked: locked, size: AppLayout.s(tile))
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { locked.toggle() }
        }
    }
}

enum AppBrand: String, Identifiable, CaseIterable {
    case instagram, snapchat, x, whatsapp
    var id: String { rawValue }
}

struct AppIconTile: View {
    let brand: AppBrand
    let locked: Bool
    var size: CGFloat = 60

    /// Use the real brand artwork from the catalog ("brand-instagram", …);
    /// fall back to the drawn rendition only if the asset is missing.
    private var assetName: String { "brand-\(brand.rawValue)" }
    private var hasAsset: Bool { UIImage(named: assetName) != nil }

    var body: some View {
        icon
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                    .stroke(Theme.ink, lineWidth: 2)
            )
            .grayscale(locked ? 0.9 : 0)
            .opacity(locked ? 0.55 : 1)
            .overlay(alignment: .bottomTrailing) {
                if locked {
                    ZStack {
                        Circle().fill(Theme.ink)
                        Image(systemName: "lock.fill")
                            .font(.system(size: size * 0.2, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: size * 0.42, height: size * 0.42)
                    .overlay(Circle().stroke(Theme.card, lineWidth: 2))
                    .offset(x: size * 0.12, y: size * 0.12)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .shadow(color: .black.opacity(locked ? 0 : 0.14), radius: 6, y: 3)
    }

    @ViewBuilder private var icon: some View {
        if hasAsset {
            Image(assetName).resizable().scaledToFill()
        } else {
            ZStack { background; glyph }
        }
    }

    @ViewBuilder private var background: some View {
        switch brand {
        case .instagram:
            LinearGradient(
                colors: [Color(hex: "#FEDA75"), Color(hex: "#FA7E1E"), Color(hex: "#D62976"),
                         Color(hex: "#962FBF"), Color(hex: "#4F5BD5")],
                startPoint: .bottomLeading, endPoint: .topTrailing)
        case .snapchat: Color(hex: "#FFFC00")
        case .x:        Color(hex: "#050505")
        case .whatsapp: Color(hex: "#25D366")
        }
    }

    @ViewBuilder private var glyph: some View {
        switch brand {
        case .instagram:
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                    .stroke(.white, lineWidth: size * 0.075)
                    .frame(width: size * 0.56, height: size * 0.56)
                Circle().stroke(.white, lineWidth: size * 0.075)
                    .frame(width: size * 0.27, height: size * 0.27)
                Circle().fill(.white)
                    .frame(width: size * 0.08, height: size * 0.08)
                    .offset(x: size * 0.17, y: -size * 0.17)
            }
        case .snapchat:
            Ghost().fill(.white)
                .frame(width: size * 0.5, height: size * 0.56)
        case .x:
            ZStack {
                Capsule().fill(.white).frame(width: size * 0.5, height: size * 0.1)
                    .rotationEffect(.degrees(45))
                Capsule().fill(.white).frame(width: size * 0.5, height: size * 0.1)
                    .rotationEffect(.degrees(-45))
            }
        case .whatsapp:
            ZStack {
                WhatsAppBubble().fill(.white)
                    .frame(width: size * 0.66, height: size * 0.66)
                Image(systemName: "phone.fill")
                    .font(.system(size: size * 0.26, weight: .regular))
                    .foregroundColor(Color(hex: "#25D366"))
                    .offset(y: -size * 0.02)
            }
        }
    }
}

/// Snapchat-style ghost: rounded head, scalloped bottom.
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
        let span = w * 0.76
        let bw = span / CGFloat(bumps)
        for i in 0..<bumps {
            let cx = r.maxX - w * 0.12 - bw * CGFloat(i) - bw / 2
            p.addArc(center: CGPoint(x: cx, y: base), radius: bw / 2,
                     startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        }
        p.closeSubpath()
        return p
    }
}

/// WhatsApp-style speech bubble (round body + tail at the bottom-left).
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
