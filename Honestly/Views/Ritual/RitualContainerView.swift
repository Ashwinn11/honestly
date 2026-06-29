import SwiftUI

/// 2-step ritual launched from Today with a chosen mood:
/// write → gratitude → completion sequence.
struct RitualContainerView: View {
    let mood: Mood

    @EnvironmentObject var journalManager: JournalManager
    @EnvironmentObject var blockingManager: BlockingManager
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0           // 0 = write, 1 = gratitude
    @State private var content = ""
    @State private var gratitude = ""

    /// Fired after the entry is saved, so Today can show the celebration over
    /// the home screen (not trapped inside this full-screen cover).
    let onFinished: () -> Void

    private let prompt: String
    private let gratitudeQuestion: GratitudeQuestion

    init(mood: Mood, onFinished: @escaping () -> Void) {
        self.mood = mood
        self.onFinished = onFinished
        let stored = UserDefaults(suiteName: AppConstants.appGroupIdentifier)?
            .string(forKey: AppConstants.keyUserOutcome) ?? ""
        let goal = Goal(rawValue: stored) ?? .clarity
        prompt = goal.dailyPrompt()
        gratitudeQuestion = GratitudeQuestion.daily()
    }

    var body: some View {
        ZStack {
            Theme.pageBackground

            VStack(spacing: 0) {
                topBar
                if step == 0 {
                    PromptView(date: Date(), mood: mood, prompt: prompt, content: $content) {
                        withAnimation { step = 1 }
                    }
                } else {
                    GratitudeView(question: gratitudeQuestion, gratitude: $gratitude) {
                        complete()
                    }
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").headerCircle()
            }
            .buttonStyle(.plain)
            Spacer()
            ProgressDots(count: 2, index: step)
            Spacer()
            Color.clear.frame(width: AppLayout.s(48), height: AppLayout.s(48))
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .contentColumn()
    }

    private func complete() {
        journalManager.markCompleted(mood: mood, content: content, gratitude: gratitude)
        blockingManager.stopBlocking()
        onFinished()
        dismiss()
    }
}
