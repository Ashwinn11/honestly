import SwiftUI
import UIKit

// MARK: - The page's theme in the environment, so whatever's printed on it uses its ink

extension EnvironmentValues {
    /// The theme of the page this view is printed on. Page furniture (date stamp, prompt, the
    /// writing itself) reads its ink from here, so it stays legible on the dark themes.
    @Entry var pageTheme: PageTheme = .paper
}

extension View {
    /// Puts the view on a themed page: the theme's paper behind it, and its ink for everything on it.
    func pageTheme(_ theme: PageTheme) -> some View {
        background(PageThemeBackground(theme: theme))
            .environment(\.pageTheme, theme)
    }
}

// MARK: - The background itself — drop-in replacement for `PaperBackground`, themed

struct PageThemeBackground: View {
    let theme: PageTheme
    /// nil: a full page, running under this phone's status bar.
    var layout: PageThemeLayout? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            PageThemeBackdrop(theme: theme)
                .colorEffect(ShaderLibrary.grain(.float(reduceMotion ? 0 : 0.045)))
            PageThemePattern(theme: theme, layout: layout ?? .page(topInset: Self.statusBarHeight))
        }
        .ignoresSafeArea()
    }

    /// How far down the screen the status bar reaches — pages run under it.
    @MainActor private static var statusBarHeight: CGFloat {
        let scene = UIApplication.shared.connectedScenes.lazy.compactMap { $0 as? UIWindowScene }.first
        return scene?.keyWindow?.safeAreaInsets.top ?? 0
    }
}

/// A theme exactly as a full page shows it, shrunk down. Patterns are laid out for the size they're
/// drawn at, so drawing one at card size would rearrange it; this draws it at the page's real
/// size and scales the result to fill the card.
struct PageThemeMiniature: View {
    let theme: PageTheme

    var body: some View {
        GeometryReader { geo in
            let page = UIScreen.main.bounds.size
            let scale = max(geo.size.width / page.width, geo.size.height / page.height)
            PageThemeBackground(theme: theme)
                .frame(width: page.width, height: page.height)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: page.width * scale, height: page.height * scale, alignment: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipped()
        .allowsHitTesting(false)
    }
}

// MARK: - Drawing the default ink in the page's ink

/// Draws the entry's default ink in the page theme's ink. Every run of journal text is stored with
/// the dark default ink, so on a dark or tinted page this swaps it as the glyphs are drawn — the
/// stored text never changes, a page can move between themes freely, and any colour the writer
/// picked is drawn exactly as picked.
final class PageInkLayoutManager: NSLayoutManager {
    /// nil on pages written in the default ink: everything draws as stored.
    var ink: UIColor? {
        didSet {
            guard ink != oldValue, let length = textStorage?.length, length > 0 else { return }
            invalidateDisplay(forCharacterRange: NSRange(location: 0, length: length))
        }
    }

    override func showCGGlyphs(_ glyphs: UnsafePointer<CGGlyph>, positions: UnsafePointer<CGPoint>,
                               count glyphCount: Int, font: UIFont, textMatrix: CGAffineTransform,
                               attributes: [NSAttributedString.Key: Any] = [:], in context: CGContext) {
        if let ink, Self.isDefaultInk(attributes[.foregroundColor] as? UIColor) {
            context.setFillColor(ink.cgColor)
        }
        super.showCGGlyphs(glyphs, positions: positions, count: glyphCount, font: font,
                           textMatrix: textMatrix, attributes: attributes, in: context)
    }

    /// Text with no colour, or with the default espresso ink (`Palette.inkUI`, #33261A).
    private static func isDefaultInk(_ color: UIColor?) -> Bool {
        guard let color else { return true }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return false }
        return abs(red - 0x33 / 255) < 0.02 && abs(green - 0x26 / 255) < 0.02 && abs(blue - 0x1A / 255) < 0.02
    }
}

private var pageInkStorageKey: UInt8 = 0

extension UITextView {
    /// Builds a TextKit 1 text view drawn by a `PageInkLayoutManager`, so its `layoutManager` is the
    /// page-ink one from the start. (Swapping one in later doesn't work: UITextView keeps handing
    /// out its original layout manager, which no longer owns the text container.)
    static func makePageInk<View: UITextView>(_ make: (NSTextContainer) -> View) -> View {
        let storage = NSTextStorage()
        let manager = PageInkLayoutManager()
        storage.addLayoutManager(manager)
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        manager.addTextContainer(container)
        let view = make(container)
        // The container reaches its layout manager and text storage only weakly; the view keeps
        // the stack alive for as long as it lives.
        objc_setAssociatedObject(view, &pageInkStorageKey, storage, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return view
    }

    /// Draws this text view's default ink in `theme`'s ink (views built with `makePageInk`).
    func applyPageInk(_ theme: PageTheme) {
        (layoutManager as? PageInkLayoutManager)?.ink = theme.tintsInk ? theme.inkUI : nil
    }
}

// MARK: - Picker sheet — a tab per group (Paper, Airy, Scattered, Prints, Dark), theme cards in a grid, tap to apply

struct ThemePickerSheet: View {
    /// What the themes are for: journal pages (page-shaped cards) or the affirmation widget
    /// (widget-shaped cards, drawn as the widget draws them).
    enum Surface { case page, widget }

    @Binding var selection: PageTheme
    var title: String = "Page theme"
    var confirmSelection = false
    var surface: Surface = .page
    @Environment(\.dismiss) private var dismiss
    @Environment(PremiumManager.self) private var premium
    @State private var initialSelection: PageTheme?
    @State private var group: PageTheme.Group = .paper
    @State private var showPaywall = false
    /// What the widget cards show: today's affirmation, the one the widget has on it now.
    @State private var sampleQuote: String = {
        let today = Affirmations.dailyLine(premium: SharedState.premiumActive)
        return today.isEmpty ? (Affirmations.library.first?.lines.first ?? "") : today
    }()

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: surface == .page ? 76 : 150), spacing: 12)]
    }
    /// Page cards are page-shaped, so each shows the whole page exactly as it will look.
    private let pageAspect = UIScreen.main.bounds.width / UIScreen.main.bounds.height

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(Text(loc: title), trailing: {
                if confirmSelection {
                    let changed = selection != (initialSelection ?? selection)
                    IconTileButton.confirm(highlighted: changed, enabled: changed) { dismiss() }
                } else {
                    IconTileButton.close { dismiss() }
                }
            })
            .padding(EdgeInsets(top: 18, leading: 20, bottom: 6, trailing: 20))

            // One group at a time, as the cover editor shows its designs.
            ChipTabs(items: PageTheme.Group.allCases, selection: $group, title: \.rawValue, icon: \.icon)
                .padding(.top, 10)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(PageTheme.allCases.filter { $0.group == group }) { theme in
                        themeCard(theme)
                    }
                }
                .padding(EdgeInsets(top: 16, leading: 20, bottom: 20, trailing: 20))
            }
        }
        .sheetBackground()
        .paywallCover(isPresented: $showPaywall)
        .onAppear {
            initialSelection = selection
            group = selection.group            // open on the tab of the theme already in use
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    private func themeCard(_ theme: PageTheme) -> some View {
        let selected = theme == selection
        // Browsing the grid is free, and so are five of the themes, one per group. Picking any
        // other is the Premium action — the theme you're already on never shows a lock, since
        // re-selecting it is a no-op either way.
        let locked = !premium.allows(.pageThemes) && !theme.isFree && !selected
        return Button {
            if locked {
                showPaywall = true
                return
            }
            Haptics.select()
            selection = theme
        } label: {
            VStack(spacing: 6) {
                preview(theme)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                    .selectedRing(selected)
                    .overlay(alignment: .topTrailing) {
                        if locked { PremiumLockBadge(size: 17).padding(6) }
                    }
                Text(loc: theme.label)
                    .font(Fonts.ui(12, selected ? .heavy : .semibold))
                    .foregroundStyle(selected ? Palette.ink : Palette.inkSoft)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            // The preview's drawing ignores touches and sits on a clear shape, so without this
            // only the name and the outline took a tap.
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.96))
    }

    @ViewBuilder private func preview(_ theme: PageTheme) -> some View {
        switch surface {
        case .page:
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .fill(.clear)
                .aspectRatio(pageAspect, contentMode: .fit)
                .overlay { PageThemeMiniature(theme: theme) }
                .overlay(alignment: .topLeading) {
                    // A line of writing, so the card shows how the ink reads on it.
                    Text(verbatim: "Aa")
                        .font(Fonts.display(14, .heavy))
                        .foregroundStyle(theme.ink)
                        .padding(8)
                }
        case .widget:
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .fill(.clear)
                .aspectRatio(WidgetThemeMiniature.widgetSize.width / WidgetThemeMiniature.widgetSize.height,
                             contentMode: .fit)
                .overlay { WidgetThemeMiniature(theme: theme, quote: sampleQuote) }
        }
    }

}

/// A theme as the medium affirmation widget draws it — no paper grain, laid out at the widget's
/// real size and shrunk — with an affirmation on it, set as the widget sets it: the chosen font,
/// in the text colour the widget would use on this theme.
private struct WidgetThemeMiniature: View {
    let theme: PageTheme
    let quote: String
    @AppStorage(SharedState.Key.affirmationWidgetFont, store: SharedState.defaults) private var fontName = "Manrope"
    @AppStorage(SharedState.Key.affirmationWidgetTextColor, store: SharedState.defaults) private var textHex = "33261A"
    static let widgetSize = CGSize(width: 338, height: 158)

    var body: some View {
        GeometryReader { geo in
            let size = Self.widgetSize
            let scale = geo.size.width / size.width
            ZStack {
                PageThemeSurface(theme: theme)
                // The medium widget's layout (`BigWinsWidgetView`).
                VStack(spacing: 5) {
                    QuoteMark(size: 18)
                    Affirmations.text(quote)
                        .font(Font((FontChoice(rawValue: fontName) ?? .manrope).uiFont(size: 19)).weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .lineLimit(4)
                        .minimumScaleFactor(0.68)
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(Color(hex: theme.widgetTextHex(chosen: textHex)))
                .padding(18)
            }
            .frame(width: size.width, height: size.height)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
        }
        .clipped()
        .allowsHitTesting(false)
    }
}
