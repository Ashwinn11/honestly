import SwiftUI
import PencilKit

/// Full-screen doodle canvas — draws with PencilKit, hands back a flat image that the editor
/// inserts exactly like a photo (JPEG over paper, so it gets the photo treatment everywhere:
/// full ↔ minimize, thumbnails, alignment).
///
/// Deliberately a custom compact tool row instead of `PKToolPicker` — the system picker floats
/// its own chrome over the whole screen and can't be styled, which fights the app's paper/ink
/// look this sheet sits inside.
struct DoodleSheet: View {
    var onDone: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var canvasView = PKCanvasView()
    @State private var tool: DoodleTool = .pen
    @State private var colorIndex = 0
    @State private var widthIndex = 1
    @State private var strokeCount = 0

    private static let colors: [Color] = [
        Palette.ink, Palette.amber, Color(hex: "D3574A"), Color(hex: "5B9A6B"),
        Color(hex: "4A7BC4"), Color(hex: "8A63B8"), Color(hex: "E38DAA"), Color(hex: "8A6A4F"),
    ]
    private static let widths: [CGFloat] = [3, 6, 12]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            DoodleCanvas(canvasView: canvasView, onStrokeCountChange: { strokeCount = $0 })
                .background(Palette.paper)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Palette.outlineSoft, lineWidth: 1.5))
                .padding(.horizontal, 16)
            toolRow
        }
        .background(PaperBackground())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear(perform: applyTool)
        .onChange(of: tool) { applyTool() }
        .onChange(of: colorIndex) { applyTool() }
        .onChange(of: widthIndex) { applyTool() }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            IconTileButton(icon: "xmark", size: 38, iconSize: 13) { dismiss() }
            Text(loc: "Doodle")
                .font(Fonts.display(19, .bold)).foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
            IconTileButton(icon: "checkmark", size: 38, iconSize: 14,
                           iconColor: strokeCount > 0 ? Palette.ink : Palette.inkSofter) {
                finish()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private var toolRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(DoodleTool.allCases) { t in
                    toolTile(icon: t.icon, active: tool == t) { tool = t }
                }
                divider
                ForEach(Array(Self.colors.enumerated()), id: \.offset) { index, color in
                    Button {
                        Haptics.select()
                        colorIndex = index
                        if tool == .eraser { tool = .pen }
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 26, height: 26)
                            .overlay(Circle().stroke(Palette.ink.opacity(colorIndex == index ? 0.9 : 0.15),
                                                     lineWidth: colorIndex == index ? 2 : 1))
                            .scaleEffect(colorIndex == index ? 1.12 : 1)
                    }
                    .buttonStyle(PressableStyle(scale: 0.85))
                }
                divider
                ForEach(Array(Self.widths.enumerated()), id: \.offset) { index, width in
                    Button {
                        Haptics.select()
                        widthIndex = index
                    } label: {
                        Circle()
                            .fill(Palette.ink.opacity(widthIndex == index ? 1 : 0.35))
                            .frame(width: 6 + width, height: 6 + width)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(PressableStyle(scale: 0.85))
                }
                divider
                toolTile(icon: "arrow.uturn.backward", active: false) {
                    canvasView.undoManager?.undo()
                    strokeCount = canvasView.drawing.strokes.count
                }
                toolTile(icon: "trash", active: false) {
                    canvasView.drawing = PKDrawing()
                    strokeCount = 0
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 12)
        .padding(.bottom, 14)
        .animation(Motion.snappy, value: tool)
        .animation(Motion.snappy, value: colorIndex)
        .animation(Motion.snappy, value: widthIndex)
    }

    private var divider: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Palette.hairline)
            .frame(width: 1.5, height: 24)
    }

    private func toolTile(icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.select()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(active ? .white : Palette.ink)
                .frame(width: 36, height: 36)
                .background(active ? Palette.amber : Palette.cream,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(active ? Palette.ink : Palette.outlineSoft, lineWidth: active ? 2 : 1.2))
        }
        .buttonStyle(PressableStyle(scale: 0.9))
    }

    private func applyTool() {
        switch tool {
        case .pen:
            canvasView.tool = PKInkingTool(.pen, color: UIColor(Self.colors[colorIndex]),
                                           width: Self.widths[widthIndex])
        case .marker:
            canvasView.tool = PKInkingTool(.marker, color: UIColor(Self.colors[colorIndex]),
                                           width: Self.widths[widthIndex] * 2.4)
        case .eraser:
            canvasView.tool = PKEraserTool(.bitmap)
        }
    }

    private func finish() {
        let drawing = canvasView.drawing
        guard !drawing.strokes.isEmpty else { return }
        // Full canvas width (so the inserted block matches the page), cropped just below the
        // lowest stroke so an almost-empty canvas doesn't insert a giant blank block.
        let canvasBounds = canvasView.bounds
        let height = min(canvasBounds.height, drawing.bounds.maxY + 32)
        let rect = CGRect(x: 0, y: 0, width: canvasBounds.width, height: max(height, 120))
        let strokes = drawing.image(from: rect, scale: 2)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        let flattened = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            UIColor(Palette.paper).setFill()
            context.fill(rect)
            strokes.draw(in: rect)
        }
        Haptics.success()
        onDone(flattened)
        dismiss()
    }
}

private enum DoodleTool: String, CaseIterable, Identifiable {
    case pen, marker, eraser
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .pen:    return "pencil.tip"
        case .marker: return "highlighter"
        case .eraser: return "eraser"
        }
    }
}

private struct DoodleCanvas: UIViewRepresentable {
    let canvasView: PKCanvasView
    var onStrokeCountChange: (Int) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = context.coordinator
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DoodleCanvas
        init(_ parent: DoodleCanvas) { self.parent = parent }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.onStrokeCountChange(canvasView.drawing.strokes.count)
        }
    }
}
