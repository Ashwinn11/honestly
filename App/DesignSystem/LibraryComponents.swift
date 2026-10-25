import SwiftUI

struct LibraryHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            IconTileButton(icon: "chevron.backward", size: 38, iconSize: 15, action: onBack)
            Text(loc: title).font(Fonts.display(26, .bold)).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct LibrarySectionTitle: View {
    let title: String
    var body: some View {
        Text(loc: title).font(Fonts.ui(14, .bold)).foregroundStyle(Palette.inkSofter)
    }
}

struct LibraryWriteRow: View {
    let placeholder: String
    let addLabel: String
    @Binding var draft: String
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            TextField(LocalizedStringKey(placeholder), text: $draft, axis: .vertical)
                .font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.ink)
                .lineLimit(2...5)
            IconTileButton(icon: "plus", size: 38, iconSize: 14, action: onAdd)
                .accessibilityLabel(Text(loc: addLabel))
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
        .background(Palette.cream, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.outlineSoft, lineWidth: 1.5))
    }
}

struct LibraryEntryRow: View {
    let line: String
    let builtIn: Bool
    let selected: Bool
    let manageLabel: String
    var selectionHint: String? = nil
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 12) {
                    SunMark(size: 26, muted: !selected).accessibilityHidden(true)
                    Group { if builtIn { Text(loc: line) } else { Text(verbatim: line) } }
                        .font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .background(selected ? Palette.iconTile : .clear, in: RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityHint(Text(loc: selectionHint ?? ""))
            Menu {
                Button("Delete", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.inkSofter).frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text(loc: manageLabel))
        }
    }
}
