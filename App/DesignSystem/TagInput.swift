import SwiftUI

/// A rounded "# tag" pill — matches the app's existing chip styling. Pass `onRemove` for an
/// editable "×" affordance (the ritual, writing today's page); omit it for read-only display
/// (`EntryDetailView`, a past page).
struct TagChip: View {
    let text: String
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 5) {
            Text("#\(text)")
                .font(Fonts.ui(12.5, .heavy))
                .foregroundStyle(Palette.ink)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Palette.inkSofter)
                }
                .buttonStyle(PressableStyle(scale: 0.85))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Palette.cream, in: Capsule())
        .overlay(Capsule().stroke(Palette.outlineSoft, lineWidth: 1.5))
    }
}

/// Premium-gated tag editor: existing chips (removable) plus an inline "+ tag" field, capped at
/// 5 — matching the app's existing "up to 5" affirmations convention. Free users see a single
/// locked row instead, mirroring `lockedAffirmationRow`'s pattern exactly.
struct TagEditorRow: View {
    @Binding var tags: [String]
    let isPremium: Bool
    let onLockTap: () -> Void

    @State private var draft = ""

    private var canAddMore: Bool { tags.count < 5 }

    var body: some View {
        if isPremium {
            unlockedRow
        } else {
            lockedRow
        }
    }

    // Plain HStack, not a ScrollView. The `TextField` is given a fixed width, not just a
    // minimum — unlike `Text`, a `TextField` genuinely expands to claim any leftover space a
    // plain HStack offers it, which is what made the input pill (and the row as a whole) balloon
    // once nothing bounded it.
    private var unlockedRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                TagChip(text: tag) {
                    withAnimation(Motion.snappy) { tags.removeAll { $0 == tag } }
                }
            }
            if canAddMore {
                HStack(spacing: 3) {
                    Text("#").font(Fonts.ui(12.5, .heavy)).foregroundStyle(Palette.inkSofter)
                    TextField(LocalizedStringKey("Add tag"), text: $draft)
                        .font(Fonts.ui(12.5, .heavy))
                        .foregroundStyle(Palette.ink)
                        .submitLabel(.done)
                        .onSubmit(commitDraft)
                        .frame(width: 70)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Palette.paper, in: Capsule())
                .overlay(Capsule().stroke(Palette.ink.opacity(0.12), lineWidth: 1.5))
            }
            Spacer(minLength: 0)
        }
    }

    private var lockedRow: some View {
        Button(action: onLockTap) {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.inkSofter)
                Text(loc: "Unlock tags")
                    .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSofter)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.hairline)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    private func commitDraft() {
        let cleaned = draft.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        defer { draft = "" }
        guard !cleaned.isEmpty, canAddMore, !tags.contains(cleaned) else { return }
        withAnimation(Motion.snappy) { tags.append(cleaned) }
        Haptics.select()
    }
}

/// Read-only chip row — past entries in `EntryDetailView`. Only rendered when tags exist.
struct TagRow: View {
    let tags: [String]

    var body: some View {
        if !tags.isEmpty {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(tags, id: \.self) { TagChip(text: $0) }
            }
        }
    }
}
