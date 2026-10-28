import SwiftUI
import UIKit

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

/// Installs one non-blocking tap recognizer on each app window. A tap anywhere except a text
/// input ends editing, while the recognizer allows the touched button or view to keep handling it.
struct KeyboardDismissalInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = KeyboardDismissalInstallerView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

private final class KeyboardDismissalInstallerView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window,
              window.gestureRecognizers?.contains(where: { $0.name == "honestly.keyboardDismissTap" }) != true
        else { return }

        let tap = UITapGestureRecognizer(target: KeyboardDismissalTapHandler.shared,
                                         action: #selector(KeyboardDismissalTapHandler.dismissKeyboard))
        tap.name = "honestly.keyboardDismissTap"
        tap.cancelsTouchesInView = false
        tap.delegate = KeyboardDismissalTapHandler.shared
        window.addGestureRecognizer(tap)
    }
}

@MainActor
private final class KeyboardDismissalTapHandler: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissalTapHandler()

    @objc func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var touchedView = touch.view
        while let view = touchedView {
            if view is UITextField || view is UITextView { return false }
            touchedView = view.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

struct LibrarySectionTitle: View {
    let title: String
    var body: some View {
        Text(loc: title).font(Fonts.ui(14, .bold)).foregroundStyle(Palette.inkSofter)
    }
}

/// Stands in for `LibraryWriteRow` when writing your own is Premium: a locked row that opens the
/// paywall. Shared by the affirmation and prompt libraries.
struct LibraryLockedWriteRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill").foregroundStyle(Palette.inkSofter)
                Text(loc: "Write your own with Premium")
                    .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSofter)
                Spacer()
            }
            .padding(14).frame(minHeight: 48)
            .background(Palette.cream, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.outlineSoft, lineWidth: 1.2))
        }
        .buttonStyle(.plain)
    }
}

struct LibraryWriteRow: View {
    let placeholder: String
    let addLabel: String
    @Binding var draft: String
    var resetToken: Int = 0
    let onAdd: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            TextField(LocalizedStringKey(placeholder), text: $draft, axis: .vertical)
                .font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.ink)
                .lineLimit(2...5)
                .focused($focused)
                .id(resetToken)
            IconTileButton(icon: "plus", size: 38, iconSize: 14, action: onAdd)
                .accessibilityLabel(Text(loc: addLabel))
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
        .background(Palette.cream, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.outlineSoft, lineWidth: 1.5))
        .onChange(of: resetToken) { _, _ in focused = true }
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
