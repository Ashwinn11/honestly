import SwiftUI

/// The pick-your-rotation list: a flat built-in library, tap a line to add or
/// remove it. Picking order is rotation order. Without Premium the list stops at
/// `Affirmations.freeLimit`; `onUpsell` decides what a tap past that does, and whether the
/// locked "write your own" row shows at all — onboarding passes nil, since its paywall is the
/// very next beat anyway. Premium installs get a live "write your own" row instead.
struct AffirmationPicker: View {
    @Binding var selection: [String]
    let isPremium: Bool
    var onUpsell: (() -> Void)? = nil
    @Environment(AffirmationList.self) private var list

    @State private var draft = ""
    @State private var pendingDelete: String?

    private var atLimit: Bool { !isPremium && selection.count >= Affirmations.freeLimit }
    private var custom: [String] { list.savedCustom }
    private var trimmedDraft: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            if isPremium || onUpsell != nil {
                LibrarySectionTitle(title: "Your own")
                if isPremium { writeRow } else { lockedWriteRow }
                ForEach(custom, id: \.self) { managedRow($0) }
            }
            let builtIn = list.availableLibrary.flatMap(\.lines)
            if !builtIn.isEmpty {
                LibrarySectionTitle(title: "Affirmations").padding(.top, 14)
                ForEach(builtIn, id: \.self) { managedRow($0) }
            }
        }
        .padding(.vertical, 4)
        .confirmationDialog("Delete affirmation?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        ), titleVisibility: .visible, presenting: pendingDelete) { line in
            Button("Delete", role: .destructive) {
                let wasPicked = selection.contains(line)
                let remaining = selection.filter { $0 != line }
                list.delete(line)
                selection = wasPicked && remaining.isEmpty ? list.initialSelection : remaining
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { _ in
            Text(loc: "This removes the affirmation from your library, widgets and reminders.")
        }
    }

    private func managedRow(_ line: String) -> some View {
        LibraryEntryRow(line: line, builtIn: Affirmations.isLibrary(line), selected: selection.contains(line),
                        manageLabel: "Manage affirmation",
                        selectionHint: selection.contains(line) ? "Remove from My affirmations" : "Add to My affirmations",
                        onSelect: { toggle(line) },
                        onDelete: { pendingDelete = line })
    }

    private var writeRow: some View {
        LibraryWriteRow(placeholder: "Write your own…", addLabel: "Add", draft: $draft, onAdd: addDraft)
    }

    private var lockedWriteRow: some View {
        Button { onUpsell?() } label: {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.inkSofter)
                    .frame(width: 26, height: 26)
                Text("Write your own with Premium")
                    .font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.inkSofter)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .padding(12)
            .background(Palette.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Palette.outlineSoft, lineWidth: 1.5))
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    // The rotation is never allowed to go empty once something's in it — there'd be nothing for
    // Home, the widget or the notification to show.
    private func toggle(_ line: String) {
        if let i = selection.firstIndex(of: line) {
            guard selection.count > 1 else { Haptics.rigid(); return }
            Haptics.select()
            withAnimation(Motion.snappy) { _ = selection.remove(at: i) }
        } else if atLimit {
            Haptics.rigid()
            onUpsell?()
        } else if !isPremium && !Affirmations.isLibrary(line) {
            Haptics.rigid()
            onUpsell?()
        } else {
            Haptics.select()
            withAnimation(Motion.snappy) { selection.append(line) }
        }
    }

    private func addDraft() {
        let line = trimmedDraft
        guard isPremium, !line.isEmpty else { return }
        let saved = list.saveCustom(line)
        guard saved || custom.contains(line) else { Haptics.rigid(); return }
        draft = ""
        Haptics.select()
        if !selection.contains(line) {
            withAnimation(Motion.snappy) { selection.append(line) }
        }
    }
}

/// How many lines are in the rotation, against the free cap when there is one.
struct AffirmationCount: View {
    let count: Int
    let isPremium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            (isPremium ? Text("\(count) in My affirmations")
                       : Text("\(count) of \(Affirmations.freeLimit) picked"))
                .font(Fonts.ui(13, .heavy)).foregroundStyle(Palette.amberDeep)
            if !isPremium && count >= Affirmations.freeLimit {
                Text("Premium adds unlimited, plus your own.")
                    .font(Fonts.ui(12.5, .semibold)).foregroundStyle(Palette.inkSofter)
                    .transition(.opacity)
            }
        }
        .animation(Motion.snappy, value: count)
    }
}

/// Home's "Edit" and Profile's "Your affirmations" row both land here: the full picker, saved as
/// you go. Pushed rather than presented as a sheet, so a paywall it raises presents from Root the
/// usual way instead of fighting a sheet for the presentation slot.
struct AffirmationsScreen: View {
    @Environment(AffirmationList.self) private var list
    @Environment(PremiumManager.self) private var premium
    @Environment(AppFlow.self) private var flow
    @Environment(\.dismiss) private var dismiss
    @State private var selection: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LibraryHeader(title: "Explore affirmations", onBack: { dismiss() })
            AffirmationCount(count: selection.count, isPremium: premium.isPremium)
            ScrollView {
                AffirmationPicker(selection: $selection, isPremium: premium.isPremium,
                                  onUpsell: { flow.showPaywall() })
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(20)
        .capWidth(Metrics.maxContentWidth)
        .background(PaperBackground())
        .toolbar(.hidden, for: .tabBar)
        .onAppear { selection = list.initialSelection }
        .onChange(of: selection) { _, picks in list.set(picks) }
    }
}
