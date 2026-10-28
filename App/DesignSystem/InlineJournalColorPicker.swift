import SwiftUI
import UIKit

/// A fixed-height color surface inside Text Formatting; it never presents another controller.
struct InlineJournalColorPicker: View {
    let color: UIColor
    let onChange: (UIColor) -> Void
    @State private var hue: Double
    @State private var saturation: Double
    @State private var brightness: Double

    init(color: UIColor, onChange: @escaping (UIColor) -> Void) {
        self.color = color
        self.onChange = onChange
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        _hue = State(initialValue: h)
        _saturation = State(initialValue: s)
        _brightness = State(initialValue: b)
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack {
                    LinearGradient(colors: [.white, Color(hue: hue, saturation: 1, brightness: 1)],
                                   startPoint: .leading, endPoint: .trailing)
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    Circle().fill(Color(hue: hue, saturation: saturation, brightness: brightness))
                        .frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .position(x: 10 + saturation * max(0, geometry.size.width - 20),
                                  y: 10 + (1 - brightness) * max(0, geometry.size.height - 20))
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.chip))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    saturation = min(1, max(0, (value.location.x - 10) / max(1, geometry.size.width - 20)))
                    brightness = 1 - min(1, max(0, (value.location.y - 10) / max(1, geometry.size.height - 20)))
                    emit()
                })
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(loc: "Color"))
                .accessibilityValue(hex)
                .accessibilityAdjustableAction { direction in
                    brightness = min(1, max(0, brightness + (direction == .increment ? 0.05 : -0.05)))
                    emit()
                }
            }
            .frame(height: 112)

            HStack(spacing: 12) {
                Slider(value: Binding(get: { hue }, set: { hue = $0; emit() }), in: 0...1) {
                    Text(loc: "Hue")
                }
                .tint(Color(hue: hue, saturation: 1, brightness: 1))
                .frame(minHeight: 44)
                Text(hex).font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(width: 70)
            }
        }
        .onChange(of: color) { _, value in
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            guard value.getHue(&h, saturation: &s, brightness: &b, alpha: nil) else { return }
            if s > 0 && b > 0 { hue = h }
            saturation = s
            brightness = b
        }
    }

    private var hex: String {
        let selected = UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        selected.getRed(&r, green: &g, blue: &b, alpha: nil)
        return String(format: "#%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    private func emit() {
        onChange(UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1))
    }
}
