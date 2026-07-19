import SwiftUI
import UIKit

/// The journal formatting toolbar — extracted from RitualView so the "edit a saved entry" screen
/// shows the identical toolbar. Sits in the footer slot while the editor has focus.
///
/// Design:
///  • Main row  — tT (text-format sheet) · Lists · Photo · Doodle · Sticker · Theme · Undo · Redo · Dismiss
///  • tT sheet  — Font | Size (with active tick) | Bold/Italic/Underline | Alignment | Color swatches
///
/// Active state is shown everywhere: ticked rows for font/size/list, amber tile for B/I/U,
/// ringed swatch for color, filled alignment button for the current alignment.
struct EditorToolbar: View {
    @Binding var text: NSAttributedString
    @Binding var selectedRange: NSRange
    var onPhoto: () -> Void
    var onDoodle: () -> Void
    var onSticker: () -> Void
    var onTheme: () -> Void
    var onDismissKeyboard: () -> Void

    @Environment(PremiumManager.self) private var premium
    @Environment(AppFlow.self) private var flow

    @State private var showTextSheet = false

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // ── tT: consolidated text-format sheet ──────────────────────
                    Button { showTextSheet = true } label: {
                        Text("tT")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 40, height: 36)
                            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Palette.outlineSoft, lineWidth: 1.2))
                    }
                    .buttonStyle(PressableStyle(scale: 0.9))

                    // ── Lists (free; ticks show active kind) ────────────────────
                    listMenu

                    // ── Media / theme ────────────────────────────────────────────
                    lockableButton(icon: "photo")              { onPhoto() }
                    lockableButton(icon: "scribble.variable")  { onDoodle() }
                    lockableButton(icon: "face.smiling")       { onSticker() }
                    lockableButton(icon: "paintbrush")         { onTheme() }

                    // ── Undo / Redo ───────────────────────────────────────────────
                    undoRedoButton(icon: "arrow.uturn.backward") {
                        NotificationCenter.default.post(name: .editorUndo, object: nil)
                    }
                    undoRedoButton(icon: "arrow.uturn.forward") {
                        NotificationCenter.default.post(name: .editorRedo, object: nil)
                    }
                }
                .padding(.horizontal, 12)
            }

            // Keyboard dismiss — always visible, never scrolled away
            toolbarButton(icon: "keyboard.chevron.compact.down") { onDismissKeyboard() }
                .padding(.trailing, 12)
        }
        .sheet(isPresented: $showTextSheet) {
            TextFormattingSheet(
                text: $text,
                selectedRange: $selectedRange,
                applyCharacter: applyCharacterFormat,
                applyParagraph: applyParagraphFormat,
                currentFont: currentFont,
                activeListKind: activeListKind,
                isBold: isBold,
                isItalic: isItalic,
                isUnderlined: isUnderlined,
                currentAlignment: currentAlignment,
                currentColor: currentTextColor,
                textColors: Self.textColors
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .environment(premium)
            .environment(flow)
        }
    }

    // MARK: List menu — shows checkmark next to the active kind; tapping it again removes the list

    private var listMenu: some View {
        Menu {
            ForEach(ListKind.allCases) { kind in
                Button {
                    applyParagraphFormat { RichTextFormatting.toggleList(kind, in: $0, range: $1) }
                } label: {
                    Label {
                        Text(kind.menuLabel)
                    } icon: {
                        Image(systemName: activeListKind == kind ? "checkmark" : kind.icon)
                    }
                }
            }
        } label: {
            toolbarIcon(activeListKind?.icon ?? "list.bullet")
        }
    }

    // MARK: Plumbing

    func applyCharacterFormat(_ transform: @escaping (NSAttributedString, NSRange) -> NSAttributedString) {
        let hasSelection = selectedRange.length > 0
        let range = hasSelection ? selectedRange : NSRange(location: 0, length: text.length)
        if !hasSelection {
            // Update Coordinator's defaultAttributes so future typing uses the new style
            NotificationCenter.default.post(name: .editorApplyDefaultTransform, object: nil,
                                            userInfo: ["transform": transform])
        }
        guard range.length > 0 else { return }
        // Route through Coordinator so the change is applied via textStorage (not the binding)
        // and registered with undoManager before being applied.
        NotificationCenter.default.post(name: .editorApplyFormatToStorage, object: nil,
                                        userInfo: ["transform": transform, "range": range])
        Haptics.select()
    }

    func applyParagraphFormat(_ transform: @escaping (NSAttributedString, NSRange) -> NSAttributedString) {
        let hasSelection = selectedRange.length > 0
        let range = hasSelection ? selectedRange : NSRange(location: 0, length: text.length)
        if !hasSelection {
            NotificationCenter.default.post(name: .editorApplyDefaultTransform, object: nil,
                                            userInfo: ["transform": transform])
        }
        guard range.length > 0 else { return }
        NotificationCenter.default.post(name: .editorApplyFormatToStorage, object: nil,
                                        userInfo: ["transform": transform, "range": range])
        Haptics.select()
    }

    // MARK: State readers

    var currentFont: UIFont {
        guard text.length > 0 else { return RichTextEditor.defaultFont }
        let loc = min(selectedRange.location, text.length - 1)
        return (text.attribute(.font, at: loc, effectiveRange: nil) as? UIFont) ?? RichTextEditor.defaultFont
    }

    // True only when there is actually a DIFFERENT family member to toggle to.
    // Fonts whose only variant is bold (Bradley Hand, Snell Roundhand, etc.) report
    // canBold = false so the button is dimmed — the font is "stuck" bold by design.
    var canBold: Bool {
        let isCurrentlyBold = currentFont.fontDescriptor.symbolicTraits.contains(.traitBold)
        if isCurrentlyBold {
            guard let nb = currentFont.removingTrait(.traitBold) else { return false }
            return nb.fontName != currentFont.fontName
        } else {
            guard let b = currentFont.addingTrait(.traitBold) else { return false }
            return b.fontName != currentFont.fontName
        }
    }
    var canItalic: Bool {
        let isCurrentlyItalic = currentFont.fontDescriptor.symbolicTraits.contains(.traitItalic)
        if isCurrentlyItalic {
            guard let ni = currentFont.removingTrait(.traitItalic) else { return false }
            return ni.fontName != currentFont.fontName
        } else {
            guard let i = currentFont.addingTrait(.traitItalic) else { return false }
            return i.fontName != currentFont.fontName
        }
    }
    // Active only when the font is bold AND can be toggled off (not inherently-bold-only fonts)
    var isBold:    Bool { currentFont.fontDescriptor.symbolicTraits.contains(.traitBold)   && canBold }
    var isItalic:  Bool { currentFont.fontDescriptor.symbolicTraits.contains(.traitItalic) && canItalic }
    var isUnderlined: Bool {
        guard text.length > 0 else { return false }
        let loc = min(selectedRange.location, text.length - 1)
        let val = text.attribute(.underlineStyle, at: loc, effectiveRange: nil) as? Int
        return (val ?? 0) != 0
    }
    var currentAlignment: NSTextAlignment {
        RichTextFormatting.alignment(in: text, at: selectedRange)
    }
    var currentTextColor: UIColor? {
        guard text.length > 0 else { return nil }
        let loc = min(selectedRange.location, text.length - 1)
        return text.attribute(.foregroundColor, at: loc, effectiveRange: nil) as? UIColor
    }
    var activeListKind: ListKind? {
        guard text.length > 0 else { return nil }
        let paraRange = RichTextFormatting.paragraphRange(in: text, for: selectedRange)
        guard paraRange.length > 0 else { return nil }
        let ns = text.string as NSString
        let para = ns.substring(with: paraRange)
        return ListKind.parseItem(para)?.kind
    }

    // MARK: Buttons

    private func lockableButton(icon: String, action: @escaping () -> Void) -> some View {
        Button {
            if premium.isPremium { action() } else { flow.showPaywall() }
        } label: {
            toolbarIcon(icon)
                .overlay(alignment: .topTrailing) { if !premium.isPremium { lockBadge } }
        }
        .buttonStyle(PressableStyle(scale: 0.9))
    }

    private func undoRedoButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { toolbarIcon(icon) }
            .buttonStyle(PressableStyle(scale: 0.9))
    }

    private func toolbarButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { toolbarIcon(icon) }
            .buttonStyle(PressableStyle(scale: 0.9))
    }

    private func toolbarIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Palette.ink)
            .frame(width: 36, height: 36)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Palette.outlineSoft, lineWidth: 1.2))
    }

    private var lockBadge: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 14, height: 14)
            .background(Palette.amber, in: Circle())
            .overlay(Circle().stroke(Palette.ink, lineWidth: 1))
            .offset(x: 4, y: -4)
    }

    static let textColors: [String] = [
        "33261A", "5D4E3E", "8A7A67", "41465C", "9E2B25", "D3574A",
        "B3402E", "E38DAA", "9C4368", "F5851F", "BC5E17", "E2A72E",
        "8A6A1F", "2F6B3C", "5B9A6B", "3E7C6B", "1F4E79", "4A7BC4",
        "6FA8DC", "2C6E8A", "5B3E8E", "8A63B8", "6E3F6B", "17151A",
    ]
}

// MARK: - List kind helpers

extension ListKind {
    var menuLabel: String {
        switch self {
        case .bullet:   return "Bullet list"
        case .star:     return "Star list"
        case .numbered: return "Numbered list"
        }
    }
}

// MARK: - tT Sheet: all text formatting in one clean panel

struct TextFormattingSheet: View {
    @Binding var text: NSAttributedString
    @Binding var selectedRange: NSRange
    var applyCharacter: (@escaping (NSAttributedString, NSRange) -> NSAttributedString) -> Void
    var applyParagraph: (@escaping (NSAttributedString, NSRange) -> NSAttributedString) -> Void
    var currentFont: UIFont
    var activeListKind: ListKind?
    var isBold: Bool
    var isItalic: Bool
    var isUnderlined: Bool
    var currentAlignment: NSTextAlignment
    var currentColor: UIColor?
    var textColors: [String]

    @Environment(PremiumManager.self) private var premium
    @Environment(AppFlow.self) private var flow
    @Environment(\.dismiss) private var dismiss

    // Detect active font choice and size from the UIFont at caret
    private var activeFontChoice: FontChoice? {
        let name = currentFont.fontName
        let family = currentFont.familyName
        for choice in FontChoice.allCases {
            let sample = choice.uiFont(size: 12)
            if sample.familyName == family { return choice }
        }
        return nil
    }

    private var activeTextSize: TextSize? {
        let pts = currentFont.pointSize
        return TextSize.allCases.min { abs($0.points - pts) < abs($1.points - pts) }
    }

    private var activeColorHex: String? {
        guard let c = currentColor else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: nil)
        let hex = String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        return textColors.first { $0.caseInsensitiveCompare(hex) == .orderedSame }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // ── Section header ─────────────────────────────────────────────
                Text("Text Formatting")
                    .font(Fonts.display(20, .bold))
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 4)

                // ── Font family ───────────────────────────────────────────────
                sheetSection(label: "Font") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(FontChoice.allCases) { choice in
                                let active = activeFontChoice == choice
                                Button {
                                    applyCharacter { RichTextFormatting.setFont(choice, in: $0, range: $1) }
                                } label: {
                                    HStack(spacing: 5) {
                                        if active { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
                                        Text(choice.rawValue).font(Font(choice.uiFont(size: 14)))
                                    }
                                    .foregroundStyle(active ? .white : Palette.ink)
                                    .padding(.horizontal, 12)
                                    .frame(height: 34)
                                    .background(
                                        active ? AnyShapeStyle(Palette.amber) : AnyShapeStyle(Palette.paper),
                                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .stroke(active ? Palette.ink : Palette.outlineSoft,
                                                    lineWidth: active ? 2 : 1.2)
                                    )
                                }
                                .buttonStyle(PressableStyle(scale: 0.92))
                                .premiumGate(premium: premium, flow: flow)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }

                // ── Size ──────────────────────────────────────────────────────
                sheetSection(label: "Size") {
                    HStack(spacing: 8) {
                        ForEach(TextSize.allCases) { size in
                            let active = activeTextSize == size
                            Button {
                                applyCharacter { RichTextFormatting.setTextSize(size, in: $0, range: $1) }
                            } label: {
                                HStack(spacing: 4) {
                                    if active { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
                                    Text(size.label).font(Fonts.ui(14, .bold))
                                }
                                .foregroundStyle(active ? .white : Palette.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(
                                    active ? AnyShapeStyle(Palette.amber) : AnyShapeStyle(Palette.paper),
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .stroke(active ? Palette.ink : Palette.outlineSoft,
                                                lineWidth: active ? 2 : 1.2)
                                )
                            }
                            .buttonStyle(PressableStyle(scale: 0.92))
                            .premiumGate(premium: premium, flow: flow)
                        }
                    }
                }

                // ── Style & Alignment ─────────────────────────────────────────
                sheetSection(label: "Style & Alignment") {
                    HStack(spacing: 8) {
                        // Bold
                        styleToggle(icon: "bold", active: isBold, enabled: currentFont.supports(.traitBold)) {
                            applyCharacter { RichTextFormatting.toggleBold($0, range: $1) }
                        }
                        .premiumGate(premium: premium, flow: flow)

                        // Italic
                        styleToggle(icon: "italic", active: isItalic, enabled: currentFont.supports(.traitItalic)) {
                            applyCharacter { RichTextFormatting.toggleItalic($0, range: $1) }
                        }
                        .premiumGate(premium: premium, flow: flow)

                        // Underline
                        styleToggle(icon: "underline", active: isUnderlined, enabled: true) {
                            applyCharacter { RichTextFormatting.toggleUnderline($0, range: $1) }
                        }
                        .premiumGate(premium: premium, flow: flow)

                        Spacer().frame(width: 8)

                        // Alignment — Left / Center / Right
                        let alignOptions: [(NSTextAlignment, String)] = [
                            (.left, "text.alignleft"),
                            (.center, "text.aligncenter"),
                            (.right, "text.alignright"),
                        ]
                        ForEach(alignOptions, id: \.1) { alignment, icon in
                            let active = currentAlignment == alignment
                            Button {
                                applyParagraph { RichTextFormatting.setAlignment(alignment, in: $0, range: $1) }
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(active ? .white : Palette.ink)
                                    .frame(width: 40, height: 36)
                                    .background(
                                        active ? AnyShapeStyle(Palette.amber) : AnyShapeStyle(Palette.paper),
                                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    )
                                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .stroke(active ? Palette.ink : Palette.outlineSoft,
                                                lineWidth: active ? 2 : 1.2))
                            }
                            .buttonStyle(PressableStyle(scale: 0.92))
                        }
                    }
                }

                // ── Colors ────────────────────────────────────────────────────
                sheetSection(label: "Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8),
                              spacing: 10) {
                        ForEach(Array(textColors.enumerated()), id: \.offset) { _, hex in
                            let isActive = activeColorHex?.caseInsensitiveCompare(hex) == .orderedSame
                            Button {
                                applyCharacter {
                                    RichTextFormatting.setTextColor(UIColor(Color(hex: hex)), in: $0, range: $1)
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 30, height: 30)
                                    if isActive {
                                        Circle()
                                            .stroke(Palette.ink, lineWidth: 2.5)
                                            .frame(width: 30, height: 30)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .black))
                                            .foregroundStyle(.white)
                                    } else {
                                        Circle()
                                            .stroke(Palette.ink.opacity(0.14), lineWidth: 1)
                                            .frame(width: 30, height: 30)
                                    }
                                }
                            }
                            .buttonStyle(PressableStyle(scale: 0.85))
                            .premiumGate(premium: premium, flow: flow)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(PaperBackground())
    }

    // MARK: Helpers

    @ViewBuilder
    private func sheetSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(Fonts.ui(10.5, .heavy))
                .foregroundStyle(Palette.inkSofter)
                .tracking(1.2)
            content()
        }
    }

    @ViewBuilder
    private func styleToggle(icon: String, active: Bool, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            if enabled { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(active ? .white : (enabled ? Palette.ink : Palette.inkSofter))
                .frame(width: 44, height: 36)
                .background(
                    active ? AnyShapeStyle(Palette.amber) : AnyShapeStyle(Palette.paper),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(active ? Palette.ink : Palette.outlineSoft,
                            lineWidth: active ? 2 : 1.2))
                .opacity(enabled ? 1 : 0.35)
        }
        .buttonStyle(PressableStyle(scale: enabled ? 0.92 : 1.0))
    }
}

// MARK: - Short labels for list kinds in the sheet

extension ListKind {
    var shortLabel: String {
        switch self {
        case .bullet:   return "Bullet"
        case .star:     return "Star"
        case .numbered: return "Number"
        }
    }
}

// MARK: - Premium gate view modifier

private struct PremiumGateModifier: ViewModifier {
    let premium: PremiumManager
    let flow: AppFlow

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            if !premium.isPremium {
                Image(systemName: "lock.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 14, height: 14)
                    .background(Palette.amber, in: Circle())
                    .overlay(Circle().stroke(Palette.ink, lineWidth: 1))
                    .offset(x: 4, y: -4)
                    .allowsHitTesting(false)
            }
        }
        .simultaneousGesture(TapGesture().onEnded {
            if !premium.isPremium { flow.showPaywall() }
        })
    }
}

private extension View {
    func premiumGate(premium: PremiumManager, flow: AppFlow) -> some View {
        modifier(PremiumGateModifier(premium: premium, flow: flow))
    }
}
