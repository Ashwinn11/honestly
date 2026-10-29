import SwiftUI
import UIKit

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

struct LibraryWriteRow: View {
    let placeholder: String
    let addLabel: String
    @Binding var draft: String
    var resetToken: Int = 0
    let onAdd: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            TextField(LocalizedStringKey(placeholder), text: $draft, axis: .vertical)
                .font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.ink)
                .lineLimit(1...5)
                .focused($focused)
                .id(resetToken)
            IconTileButton(icon: "plus", size: 38, iconSize: 14, action: onAdd)
                .accessibilityLabel(Text(loc: addLabel))
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
        .outlinedSurface()
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
                HStack(alignment: .center, spacing: 12) {
                    Circle()
                        .fill(selected ? Palette.amber : Palette.ink.opacity(0.12))
                        .frame(width: selected ? 8 : 6, height: selected ? 8 : 6)
                        .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 1))
                        .accessibilityHidden(true)
                    Group { if builtIn { Text(loc: line) } else { Text(verbatim: line) } }
                        .font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .background(selected ? Palette.iconTile : .clear, in: RoundedRectangle(cornerRadius: Radius.chip))
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
