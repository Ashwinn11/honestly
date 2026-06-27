import SwiftUI

struct PromptView: View {
    let date: Date
    let mood: Mood
    let prompt: String
    @Binding var content: String
    let onNext: () -> Void

    @FocusState private var focused: Bool

    private var wordCount: Int {
        content.split { $0 == " " || $0 == "\n" }.count
    }
    private var encouraged: Bool { wordCount >= JournalManager.encouragedWordCount }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    promptCard
                    editor
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }

            footer
        }
        .onAppear { focused = true }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(date.formatted(.dateTime.weekday(.wide)).uppercased(), size: 18)
                Text(date.formatted(.dateTime.month(.wide).day()))
                    .font(AppFont.title(34))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            VStack(spacing: 4) {
                MoodFace(mood: mood, size: 64)
                Text(mood.feelingLabel)
                    .font(AppFont.accent(15))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
    }

    private var promptCard: some View {
        AppCard(padding: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("TODAY'S PROMPT")
                    .font(AppFont.captionBold(13))
                    .foregroundStyle(Theme.inkFaint)
                    .tracking(1)
                Text(prompt)
                    .font(AppFont.accent(19))
                    .foregroundStyle(Theme.ink)
            }
        }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            LinedPaper()
            if content.isEmpty {
                Text("start anywhere. it'll come…")
                    .font(AppFont.body(17))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 10)
            }
            TextEditor(text: $content)
                .font(AppFont.body(17))
                .foregroundStyle(Theme.ink)
                .lineSpacing(16)
                .frame(minHeight: 220)
                .scrollContentBackground(.hidden)
                .focused($focused)
            PlantView(stage: .sprout, size: 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .allowsHitTesting(false)
        }
        .padding(16)
        .appCardStyle(fill: Theme.paper)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Text("\(wordCount) words · keep going")
                    .font(AppFont.caption(14))
                    .foregroundStyle(encouraged ? Theme.orange : Theme.inkFaint)
                if encouraged {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.orange)
                }
                Spacer()
            }
            // No gate — always tappable. Styling only reflects encouragement.
            PrimaryButton(title: "next: gratitude",
                          fill: encouraged ? Theme.orange : Theme.dark,
                          icon: "heart.fill",
                          action: onNext)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }
}
