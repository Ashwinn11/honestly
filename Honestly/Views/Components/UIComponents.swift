import SwiftUI

// MARK: - AppCard

struct AppCard<Content: View>: View {
    var padding: CGFloat = 20
    var radius: CGFloat = Theme.cardRadius
    var fill: Color = Theme.card
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCardStyle(radius: radius, fill: fill)
    }
}

// MARK: - Colored icon badge (for options / feature rows)

struct ColorIconBadge: View {
    let icon: String
    let color: Color
    var size: CGFloat = 52

    var body: some View {
        let d = AppLayout.s(size)
        Image(systemName: icon)
            .font(.system(size: d * 0.42, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(width: d, height: d)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: d * 0.3, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: d * 0.3, style: .continuous)
                    .stroke(Theme.ink, lineWidth: AppLayout.s(2))
            )
    }
}

// MARK: - Eyebrow (handwriting accent label)

struct Eyebrow: View {
    let text: String
    var color: Color = Theme.orange
    var size: CGFloat = 20

    init(_ text: String, color: Color = Theme.orange, size: CGFloat = 20) {
        self.text = text
        self.color = color
        self.size = size
    }

    var body: some View {
        Text(text)
            .font(AppFont.eyebrow(size))
            .foregroundStyle(color)
    }
}

// MARK: - Buttons

struct PrimaryButton: View {
    let title: String
    var fill: Color = Theme.orange
    var textColor: Color = .white
    var icon: String? = nil            // trailing SF Symbol
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                if let icon {
                    Image(systemName: icon).font(.system(size: 16, weight: .bold))
                }
            }
            .font(AppFont.button())
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppLayout.s(18))
            .background(fill)
            .clipShape(Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).stroke(Theme.ink, lineWidth: Theme.borderWidth))
            .background(Capsule(style: .continuous).fill(Theme.ink).offset(y: Theme.shadowOffset))
        }
        .buttonStyle(.plain)
    }
}

/// Eyebrow accent with a leading SF Symbol instead of an emoji.
struct IconEyebrow: View {
    let icon: String
    let text: String
    var color: Color = Theme.orange
    var size: CGFloat = 18

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: size * 0.8, weight: .semibold))
            Eyebrow(text, color: color, size: size)
        }
        .foregroundStyle(color)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.button())
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppLayout.s(18))
                .background(Theme.card)
                .clipShape(Capsule(style: .continuous))
                .overlay(Capsule(style: .continuous).stroke(Theme.ink, lineWidth: Theme.borderWidth))
                .background(Capsule(style: .continuous).fill(Theme.ink).offset(y: Theme.shadowOffset))
        }
        .buttonStyle(.plain)
    }
}

/// Round white back/close button with chevron or x.
struct CircleIconButton: View {
    var systemName: String = "chevron.left"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: AppLayout.s(18), weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: AppLayout.s(56), height: AppLayout.s(56))
                .background(Theme.card)
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.ink, lineWidth: Theme.borderWidth))
                .background(Circle().fill(Theme.ink).offset(y: Theme.shadowOffset))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Header icon chrome

extension View {
    /// Flat circular chrome for header actions (back / close / search / share).
    /// One consistent, iPad-scaled size across the whole app. Apply to the icon Image.
    func headerCircle() -> some View {
        self
            .font(.system(size: AppLayout.s(17), weight: .bold))
            .foregroundStyle(Theme.ink)
            .frame(width: AppLayout.s(48), height: AppLayout.s(48))
            .background(Theme.card).clipShape(Circle())
            .overlay(Circle().stroke(Theme.ink, lineWidth: Theme.borderWidth))
    }
}

// MARK: - Progress dots

struct ProgressDots: View {
    let count: Int
    let index: Int    // 0-based current step

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(color(for: i))
                    .frame(width: AppLayout.s(i == index ? 26 : 9), height: AppLayout.s(9))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: index)
            }
        }
    }

    private func color(for i: Int) -> Color {
        if i < index { return Theme.orange }
        if i == index { return Theme.orange }
        return Theme.inkGhost
    }
}

// MARK: - Lined paper (journal editor / detail background)

struct LinedPaper: View {
    var lineSpacing: CGFloat = 44
    var lineColor: Color = Theme.ink.opacity(0.06)

    var body: some View {
        GeometryReader { geo in
            Path { p in
                var y = lineSpacing
                while y < geo.size.height {
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    y += lineSpacing
                }
            }
            .stroke(lineColor, lineWidth: 1)
        }
    }
}

// MARK: - Pastel tape corner (decorative sticker on journal cards)

struct TapeCorner: View {
    var color: Color
    var body: some View {
        Rectangle()
            .fill(color.opacity(0.5))
            .frame(width: 56, height: 22)
            .rotationEffect(.degrees(-18))
    }
}
