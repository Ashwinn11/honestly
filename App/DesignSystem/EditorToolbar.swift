import SwiftUI
import UIKit

/// The journal formatting toolbar — extracted from RitualView so the "edit a saved entry" screen
/// shows the identical toolbar. Sits in the footer slot while the editor has focus.
///
/// Design:
///  • Main row  — tT (text-format sheet) · Tags · Photo · Doodle · Sticker · Theme · Dismiss
///  • tT sheet  — Font / Color / Highlight tabs; inline color surfaces and quick swatches
///
/// Active state is shown everywhere: ticked rows for font/size/list, amber tile for B/I/U,
/// ringed swatch for color, filled alignment button for the current alignment.
struct EditorToolbar: View {
    @Binding var text: NSAttributedString
    @Binding var selectedRange: NSRange
    var tagCount: Int
    var onTags: () -> Void
    var onPhoto: () -> Void
    var onDoodle: () -> Void
    var onSticker: () -> Void
    var onTheme: () -> Void
    var onDismissKeyboard: () -> Void
    var onFormattingOpened: () -> Void
    var onFormattingClosed: () -> Void
    /// A locked tool was tapped. The screen hosting the toolbar shows the paywall — it may itself
    /// be a cover, where the app-wide paywall can't appear.
    var onLocked: () -> Void
    /// The page theme's text colour — what text with no colour of its own shows in.
    var pageInk: Color

    @Environment(PremiumManager.self) private var premium

    @State private var showTextSheet = false

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // ── tT: consolidated text-format sheet ──────────────────────
                    Button { onFormattingOpened(); showTextSheet = true } label: {
                        Text(verbatim: "tT")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .compactControl()
                    }
                    .buttonStyle(PressableStyle())


                    Button(action: onTags) {
                        toolbarIcon("tag")
                            .overlay(alignment: .topTrailing) {
                                if tagCount > 0 {
                                    Text(tagCount, format: .number)
                                        .font(Fonts.ui(9, .heavy)).foregroundStyle(.white)
                                        .frame(width: 16, height: 16)
                                        .background(Palette.amber, in: Circle())
                                        .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 1.5))
                                        .offset(x: 4, y: -4)
                                }
                            }
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(Text(loc: "Tags"))
                    .accessibilityValue(Text(tagCount, format: .number))

                    // ── Media / theme ────────────────────────────────────────────
                    // Photos/doodles: first one is free, a second (or more) needs premium.
                    // Stickers/theme open unlocked too — each sheet shows its own free vs.
                    // premium items with a lock badge, rather than gating the button itself.
                    mediaButton(icon: "photo", isLocked: photoInsertLocked)             { onPhoto() }
                    mediaButton(icon: "scribble.variable", isLocked: photoInsertLocked) { onDoodle() }
                    toolbarButton(icon: "face.smiling") { onSticker() }
                    toolbarButton(icon: "paintbrush")   { onTheme() }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .scrollClipDisabled()

            // Keyboard dismiss — always visible, never scrolled away
            toolbarButton(icon: "keyboard.chevron.compact.down") { onDismissKeyboard() }
                .padding(.trailing, 12)
        }
        .capWidth(Metrics.maxContentWidth)
        .sheet(isPresented: $showTextSheet, onDismiss: onFormattingClosed) {
            TextFormattingSheet(
                text: $text,
                selectedRange: $selectedRange,
                applyCharacter: applyCharacterFormat,
                applyParagraph: applyParagraphFormat,
                currentFont: currentFont,
                activeListKind: activeListKind,
                isBold: isBold,
                isItalic: isItalic,
                canBold: canBold,
                canItalic: canItalic,
                isUnderlined: isUnderlined,
                currentAlignment: currentAlignment,
                currentColor: currentTextColor,
                currentHighlight: currentHighlight,
                pageInk: UIColor(pageInk)
            )
            .presentationDetents([.medium, .large])
            .presentationContentInteraction(.scrolls)
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
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
    var currentHighlight: UIColor? {
        guard text.length > 0 else { return nil }
        let loc = min(selectedRange.location, text.length - 1)
        return text.attribute(.backgroundColor, at: loc, effectiveRange: nil) as? UIColor
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

    /// Photos and doodles share one attachment kind (`.photo` — see `RichTextFormatting.kind`),
    /// so the free tier's "one photo" allowance is counted across both together, not per-source.
    private var photoAttachmentCount: Int {
        var count = 0
        text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length), options: []) { value, _, _ in
            guard let attachment = value as? NSTextAttachment,
                  RichTextFormatting.kind(of: attachment) == .photo else { return }
            count += 1
        }
        return count
    }

    /// A page's first photos/doodles are free; more need Premium.
    private var photoInsertLocked: Bool {
        !premium.allows(.morePhotos) && photoAttachmentCount >= PremiumFeature.freePhotosPerPage
    }

    private func mediaButton(icon: String, isLocked: Bool, action: @escaping () -> Void) -> some View {
        Button {
            if isLocked { onLocked() } else { action() }
        } label: {
            toolbarIcon(icon)
                .overlay(alignment: .topTrailing) { if isLocked { PremiumLockBadge(size: 14).offset(x: 4, y: -4) } }
        }
        .buttonStyle(PressableStyle())
    }

    private func toolbarButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { toolbarIcon(icon) }
            .accessibilityIdentifier("editor.toolbar.\(icon)")
            .buttonStyle(PressableStyle())
    }

    private func toolbarIcon(_ systemName: String) -> some View {
        CompactIconFace(icon: systemName)
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
    var canBold: Bool
    var canItalic: Bool
    var isUnderlined: Bool
    var currentAlignment: NSTextAlignment
    var currentColor: UIColor?
    var currentHighlight: UIColor?
    /// The page theme's text colour. Text is stored in the default ink and drawn in the theme's,
    /// so text with no colour of its own shows in this — white on a dark page.
    var pageInk: UIColor

    @Environment(\.dismiss) private var dismiss

    private enum Panel: String, CaseIterable {
        case font = "Font", color = "Color", highlight = "Highlight"
        var icon: String {
            switch self {
            case .font: "textformat"
            case .color: "paintpalette"
            case .highlight: "highlighter"
            }
        }
    }
    @State private var panel: Panel = .font

    // Detect active font choice and size from the UIFont at caret
    private var activeFontChoice: FontChoice? {
        FontChoice.matching(familyName: currentFont.familyName)
    }

    private var activeTextSize: TextSize? {
        let pts = currentFont.pointSize
        return TextSize.allCases.min { abs($0.points - pts) < abs($1.points - pts) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScreenHeader(Text("Text Formatting"), trailing: {
                IconTileButton.close { dismiss() }
            })
            ChipTabs(items: Panel.allCases, selection: $panel, title: \.rawValue, icon: \.icon, inset: 16)
                .padding(.horizontal, -16)          // the row runs edge to edge; its chips keep the margin

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if panel == .font {
                // ── Font family ───────────────────────────────────────────────
                sheetSection(label: "Font") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(FontChoice.allCases) { choice in
                                FontChip(choice: choice, selected: activeFontChoice == choice) {
                                    applyCharacter { RichTextFormatting.setFont(choice, in: $0, range: $1) }
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 3)
                    }
                    .scrollClipDisabled()
                }

                HStack(alignment: .top, spacing: 12) {
                    sheetSection(label: "Size") {
                        Menu {
                            ForEach(TextSize.allCases) { size in
                                Button {
                                    applyCharacter { RichTextFormatting.setTextSize(size, in: $0, range: $1) }
                                } label: {
                                    Label { Text(loc: size.label) } icon: {
                                        if activeTextSize == size { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        } label: { pickerLabel(activeTextSize?.label ?? "Body") }
                    }
                    sheetSection(label: "List") {
                        Menu {
                            Button {
                                applyParagraph { RichTextFormatting.setList(nil, in: $0, range: $1) }
                            } label: {
                                Label { Text(loc: "No list") } icon: {
                                    if activeListKind == nil { Image(systemName: "checkmark") }
                                }
                            }
                            ForEach(ListKind.allCases) { kind in
                                Button {
                                    applyParagraph { RichTextFormatting.setList(kind, in: $0, range: $1) }
                                } label: {
                                    Label { Text(loc: kind.menuLabel) } icon: {
                                        Image(systemName: activeListKind == kind ? "checkmark" : kind.icon)
                                    }
                                }
                            }
                        } label: { pickerLabel(activeListKind?.menuLabel ?? "No list") }
                    }
                }

                // ── Style & Alignment ─────────────────────────────────────────
                sheetSection(label: "Style & Alignment") {
                    HStack(spacing: 8) {
                        // Bold
                        styleToggle(icon: "bold", active: isBold, enabled: canBold) {
                            applyCharacter { RichTextFormatting.toggleBold($0, range: $1) }
                        }

                        // Italic
                        styleToggle(icon: "italic", active: isItalic, enabled: canItalic) {
                            applyCharacter { RichTextFormatting.toggleItalic($0, range: $1) }
                        }

                        // Underline
                        styleToggle(icon: "underline", active: isUnderlined, enabled: true) {
                            applyCharacter { RichTextFormatting.toggleUnderline($0, range: $1) }
                        }

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
                                CompactIconFace(icon: icon, active: active)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }

                    } else {
                        colorPanel
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, 20)               // inside the scroll, so nothing ends short of the edge
            }
        }
        .padding(EdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 16))
        .sheetBackground()
    }

    private var editingHighlight: Bool { panel == .highlight }
    private var selectedColor: UIColor? { editingHighlight ? currentHighlight : shownTextColor }

    /// The colour the text at the caret actually shows in: its own, or — when it still has the
    /// default ink every page stores — the page theme's.
    private var shownTextColor: UIColor {
        guard let currentColor, !Self.sameColor(currentColor, Palette.inkUI) else { return pageInk }
        return currentColor
    }

    private static func sameColor(_ a: UIColor, _ b: UIColor) -> Bool {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return abs(ar - br) < 0.01 && abs(ag - bg) < 0.01 && abs(ab - bb) < 0.01 && abs(aa - ba) < 0.01
    }

    /// Three rows each. Text: neutrals (white and cream for dark pages), warm, cool — six across.
    /// Highlight: "no highlight" and twenty highlighter colours — seven across.
    private static let quickTextColors = [
        "33261A", "5D4E3E", "8A7A67", "17151A", "FFFFFF", "F3E9D2",
        "9E2B25", "D3574A", "E38DAA", "F5851F", "E2A72E", "BC5E17",
        "2F6B3C", "5B9A6B", "1F4E79", "4A7BC4", "5B3E8E", "8A63B8",
    ]
    private static let quickHighlightColors = [
        "FFE89A", "FFD8B5", "F8C9D9", "DDCFF1", "C8E1FA", "CDE8CB",
        "FFF3B0", "FFC9A3", "FFB3C1", "E9C7F2", "B9E4F5", "BFE8D9", "E8F2B8",
        "F2D16B", "F4A988", "E58FA8", "B8A3E6", "8EC3EA", "9ED9B5", "D9CFC1",
    ]
    private var quickColors: [String] { editingHighlight ? Self.quickHighlightColors : Self.quickTextColors }

    private var colorPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            InlineJournalColorPicker(
                color: selectedColor ?? UIColor(Palette.highlighter),
                onChange: { applyColor($0) }
            )
            .id(panel)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: editingHighlight ? 7 : 6), spacing: 8) {
                if editingHighlight {
                    let active = currentHighlight == nil || currentHighlight?.cgColor.alpha == 0
                    Button { applyColor(nil) } label: {
                        Circle().fill(Palette.paper).frame(width: 32, height: 32)
                            .overlay(Circle().strokeBorder(Palette.ink, lineWidth: active ? 2.5 : 0.5))
                            .overlay(Image(systemName: "nosign").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(Text(loc: "No highlight"))
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
                ForEach(quickColors, id: \.self) { hex in
                    let color = UIColor(Color(hex: hex))
                    ColorSwatch(color: Color(hex: hex),
                                selected: selectedColor.map { Self.sameColor($0, color) } == true) { applyColor(color) }
                        .accessibilityLabel(Text(loc: panel.rawValue) + Text(" #" + hex))
                }
            }

        }
    }

    private func applyColor(_ color: UIColor?) {
        if editingHighlight {
            applyCharacter { RichTextFormatting.setHighlight(color, in: $0, range: $1) }
        } else if let color {
            applyCharacter { RichTextFormatting.setTextColor(color, in: $0, range: $1) }
        }
    }

    // MARK: Helpers

    private func pickerLabel(_ selection: String) -> some View {
        HStack(spacing: 8) {
            Text(loc: selection).font(Fonts.ui(13, .bold)).lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 44)
        .outlinedSurface(radius: Radius.tile, bold: true)
    }

    @ViewBuilder
    private func sheetSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: label, tracking: 1.2, size: 10.5)
            content()
        }
    }

    @ViewBuilder
    private func styleToggle(icon: String, active: Bool, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            if enabled { action() }
        } label: {
            CompactIconFace(icon: icon, active: active)
                .opacity(enabled ? 1 : 0.35)
        }
        .buttonStyle(PressableStyle(scale: enabled ? 0.96 : 1.0))
        .disabled(!enabled)
    }
}
