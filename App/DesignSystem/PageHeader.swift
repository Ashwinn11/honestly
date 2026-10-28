import SwiftUI

// MARK: - The page's header

/// The top of every page — writing, editing and reading alike: the day, big, over its month and
/// year; the mood; then the page's controls in the app's icon tiles. It's printed on the page,
/// not a bar above it.
struct PageHeader<Controls: View>: View {
    let date: Date
    let mood: Int?                       // nil while writing and not yet picked: shows the first face
    var onMood: (() -> Void)?            // nil: the mood is read-only
    var controls: Controls

    init(date: Date, mood: Int?, onMood: (() -> Void)? = nil, @ViewBuilder controls: () -> Controls) {
        self.date = date
        self.mood = mood
        self.onMood = onMood
        self.controls = controls()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            PageDateStamp(date: date)
            Spacer(minLength: 8)
            moodFace
            controls
        }
    }

    @ViewBuilder private var moodFace: some View {
        let shown = mood ?? 0
        let name = Mood(rawValue: shown)?.label ?? ""
        let label = Text(loc: name)
        // The face with its name beneath, so the mood reads at a glance.
        let face = VStack(spacing: 2) {
            MoodFace(mood: shown, size: DesignScale.s(30))
            Text(loc: name)
                .font(Fonts.ui(10, .bold))
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .anchorPreference(key: CoachAnchorKey.self, value: .bounds) { anchor in [CoachAnchor.mood: anchor] }
        if let onMood {
            Button { Haptics.select(); onMood() } label: { face }
                .buttonStyle(PressableStyle(scale: 0.88))
                .accessibilityLabel(label)
                .accessibilityHint(Text(loc: "How are you feeling?"))
        } else {
            face.accessibilityElement(children: .ignore).accessibilityLabel(label)
        }
    }
}

/// The page's close control, in the app's icon tile.
struct PageCloseButton: View {
    var action: () -> Void

    init(action: @escaping () -> Void) { self.action = action }

    var body: some View {
        IconTileButton.close(action)
    }
}

/// The date as a journal stamps it: the day, big, and the month and year beneath it stretched to
/// exactly the day's width.
struct PageDateStamp: View {
    let date: Date

    var body: some View {
        let gap = DesignScale.s(-5)
        let small = DesignScale.s(12)
        Text(verbatim: HDate.dayNumber(date))
            .font(Fonts.display(44, .heavy))
            .tracking(-2)
            .foregroundStyle(Palette.ink)
            .fixedSize()
            .padding(.bottom, small + gap)
            .overlay(alignment: .bottom) {
                HStack(spacing: 0) {
                    Text(verbatim: monthPart)
                    Spacer(minLength: 3)
                    Text(verbatim: HDate.year(date))
                }
                .font(Fonts.ui(12, .heavy))
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: HDate.dayMonthYear(date)))
    }

    /// "Oct," — the comma reads naturally after a Latin month, not after 10月 or 10월.
    private var monthPart: String {
        let month = HDate.monthShort(date)
        let noComma = ["ja", "ko", "zh"].contains { SharedState.language.hasPrefix($0) }
        return noComma ? month : month + ","
    }
}

// MARK: - The day's prompt, faint, where the writing goes

/// Today's question, printed faintly where the first words will go and gone once they do. A small
/// list mark at its very end says it can be changed: tapping the question opens the prompt list,
/// to pick another or write one's own.
struct PagePromptHint: View {
    let text: String
    var onChoose: () -> Void

    init(text: String, onChoose: @escaping () -> Void) {
        self.text = text
        self.onChoose = onChoose
    }

    var body: some View {
        Button { Haptics.tap(); onChoose() } label: {
            (Text(verbatim: text + "\u{00A0}\u{00A0}").foregroundStyle(Palette.ink.opacity(0.34))
             + Text(Image(systemName: "list.bullet")).font(.system(size: DesignScale.s(16), weight: .bold))
                .foregroundStyle(Palette.inkSoft))
                .font(Fonts.display(21, .heavy))
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.98))
        .anchorPreference(key: CoachAnchorKey.self, value: .bounds) { anchor in [CoachAnchor.prompt: anchor] }
        .accessibilityLabel(Text(verbatim: text))
        .accessibilityHint(Text("Choose a prompt"))
    }
}

/// On a written page, the question it answered: small and faint above the words.
struct PageAnsweredPrompt: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(Fonts.ui(15, .heavy))
            .foregroundStyle(Palette.ink.opacity(0.42))
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 14)
    }
}
