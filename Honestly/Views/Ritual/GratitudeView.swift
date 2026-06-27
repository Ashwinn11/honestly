import SwiftUI

struct GratitudeView: View {
    let question: GratitudeQuestion
    @Binding var gratitude: String
    let onFinish: () -> Void

    @FocusState private var focused: Bool

    // Pastel chip backgrounds, cycled across the suggestions.
    private let chipColors: [Color] = [Theme.happy, Theme.sad, Theme.cry, Theme.confused, Theme.gratitude]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Eyebrow("❤️ GRATEFUL FOR", size: 18)

                    Text(question.question)
                        .font(AppFont.cardTitle(26))
                        .foregroundStyle(Theme.ink)

                    chips
                    editor
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            footer
        }
        .onAppear { focused = true }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(question.chips.enumerated()), id: \.offset) { i, chip in
                    Button { gratitude = chip } label: {
                        Text(chip)
                            .font(AppFont.accent(17))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 18).padding(.vertical, 12)
                            .background(chipColors[i % chipColors.count].opacity(0.7))
                            .clipShape(Capsule(style: .continuous))
                            .overlay(Capsule(style: .continuous).stroke(Theme.ink, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            LinedPaper()
            if gratitude.isEmpty {
                Text("a person, a smell, a moment…")
                    .font(AppFont.body(17))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.horizontal, 6).padding(.vertical, 10)
            }
            TextEditor(text: $gratitude)
                .font(AppFont.body(17))
                .foregroundStyle(Theme.ink)
                .lineSpacing(16)
                .frame(minHeight: 180)
                .scrollContentBackground(.hidden)
                .focused($focused)
            Mascot(kind: .flower, size: 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .allowsHitTesting(false)
        }
        .padding(16)
        .appCardStyle(fill: Theme.paper)
    }

    private var footer: some View {
        PrimaryButton(title: "finish & unlock 🔒", action: onFinish)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
    }
}
