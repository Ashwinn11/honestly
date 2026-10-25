import SwiftUI

struct PromptLibraryScreen: View {
    @Environment(PromptLibrary.self) private var prompts
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var pendingDelete: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LibraryHeader(title: "Choose a prompt", onBack: { dismiss() })
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    LibrarySectionTitle(title: "Your own")
                    LibraryWriteRow(placeholder: "Write your own prompt…", addLabel: "Add prompt",
                                    draft: $draft, onAdd: add)

                    ForEach(prompts.custom, id: \.self) { row($0, builtIn: false) }
                    if !prompts.builtIn.isEmpty {
                        LibrarySectionTitle(title: "Prompts")
                            .padding(.top, 14)
                        ForEach(prompts.builtIn, id: \.self) { row($0, builtIn: true) }
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(20)
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

    private func add() {
        guard prompts.add(draft) else { Haptics.rigid(); return }
        draft = ""
        Haptics.select()
        dismiss()
    }
}
