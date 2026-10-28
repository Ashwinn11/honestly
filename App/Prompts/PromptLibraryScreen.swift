import SwiftUI

struct PromptLibraryScreen: View {
    @Environment(PromptLibrary.self) private var prompts
    @Environment(PremiumManager.self) private var premium
    @Environment(AppFlow.self) private var flow
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var pendingDelete: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LibraryHeader(title: "Choose a prompt", onBack: { dismiss() })
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    LibrarySectionTitle(title: "Your own")
                    // Writing your own is Premium: free accounts see the same locked row as
                    // affirmations instead of a box that only asks for Premium on +.
                    if premium.allows(.ownPrompts) {
                        LibraryWriteRow(placeholder: "Write your own prompt…", addLabel: "Add prompt",
                                        draft: $draft, onAdd: add)
                    } else {
                        PremiumLockedRow(title: "Write your own with Premium") { flow.showPaywall() }
                    }

                    ForEach(prompts.custom, id: \.self) { row($0, builtIn: false) }
                    if !prompts.builtIn.isEmpty {
                        LibrarySectionTitle(title: "Prompts")
                            .padding(.top, 14)
                        ForEach(prompts.builtIn, id: \.self) { row($0, builtIn: true) }
                    }
                }
                .padding(.top, 4)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .capWidth(Metrics.maxContentWidth)
        .background(PaperBackground())
        .confirmationDialog("Delete prompt?", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
        ), titleVisibility: .visible, presenting: pendingDelete) { line in
            Button("Delete", role: .destructive) { prompts.delete(line); pendingDelete = nil }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { _ in
            Text(loc: "This removes the prompt from your library.")
        }
    }

    private func row(_ line: String, builtIn: Bool) -> some View {
        LibraryEntryRow(line: line, builtIn: builtIn, selected: prompts.selected == line,
                        manageLabel: "Manage prompt", onSelect: {
            prompts.select(line)
            Haptics.select()
            dismiss()
        }, onDelete: { pendingDelete = line })
    }

    /// Choosing from the list is free; writing your own prompt is Premium.
    private func add() {
        guard premium.allows(.ownPrompts) else { flow.showPaywall(); return }
        guard prompts.add(draft) else { Haptics.rigid(); return }
        draft = ""
        Haptics.select()
        dismiss()
    }
}
