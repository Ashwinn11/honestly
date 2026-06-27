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
    @State private var showCompletion = false

    private let prompt: String
    private let gratitudeQuestion: GratitudeQuestion

    init(mood: Mood) {
        self.mood = mood
        let stored = UserDefaults(suiteName: AppConstants.appGroupIdentifier)?
            .string(forKey: AppConstants.keyUserOutcome) ?? ""
        let goal = Goal(rawValue: stored) ?? .clarity
        prompt = goal.dailyPrompt()
        gratitudeQuestion = GratitudeQuestion.daily()
    }

    var body: some View {
        ZStack {
            Theme.pageBackground

            if showCompletion {
                CompletionView(stage: journalManager.currentStage,
                               sproutCount: journalManager.sproutCount) {
                    dismiss()
                }
                .transition(.opacity)
            } else {
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
        .animation(.easeInOut(duration: 0.25), value: showCompletion)
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 52, height: 52)
                    .background(Theme.card)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.ink, lineWidth: Theme.borderWidth))
            }
            .buttonStyle(.plain)
            Spacer()
            ProgressDots(count: 2, index: step)
            Spacer()
            Color.clear.frame(width: 52, height: 52)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private func complete() {
        journalManager.markCompleted(mood: mood, content: content, gratitude: gratitude)
        blockingManager.stopBlocking()
        withAnimation { showCompletion = true }
    }
}
