import SwiftUI

/// The pick-your-rotation list: the built-in library grouped by focus, tap a line to add or
/// remove it. Picking order is rotation order. Without Premium the list stops at
/// `Affirmations.freeLimit`; `onUpsell` decides what a tap past that does, and whether the
/// locked "write your own" row shows at all — onboarding passes nil, since its paywall is the
/// very next beat anyway. Premium installs get a live "write your own" row instead.
struct AffirmationPicker: View {
    @Binding var selection: [String]
    let isPremium: Bool
    var onUpsell: (() -> Void)? = nil

    @State private var draft = ""

    private var atLimit: Bool { !isPremium && selection.count >= Affirmations.freeLimit }
    private var custom: [String] { selection.filter { !Affirmations.isLibrary($0) } }
    private var trimmedDraft: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Affirmations.library) { focus in
                sectionTitle(focus.title)
                VStack(spacing: 10) {
                    ForEach(focus.lines, id: \.self) { row($0) }
                }
            }
            if isPremium || onUpsell != nil {
                sectionTitle("Your own")
                VStack(spacing: 10) {
                    ForEach(custom, id: \.self) { row($0) }
                    if isPremium { writeRow } else { lockedWriteRow }
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Eyebrow(text: title, color: Palette.inkSoft, tracking: 1.2, size: 11)
            .padding(.top, 22).padding(.bottom, 10)
    }

    // Same lit/unlit treatment the ritual's old write-your-own rows used: the sun fills in once
    // a line is part of the rotation.
    private func row(_ line: String) -> some View {
        let picked = selection.contains(line)
        return Button { toggle(line) } label: {
            HStack(spacing: 12) {
                SunMark(size: 26, muted: !picked)
                    .scaleEffect(picked ? 1.08 : 1)
                    .animation(Motion.pop, value: picked)
                Affirmations.text(line)
                    .font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
            .background(picked ? Palette.iconTile : .white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(picked ? Palette.outlineSoft : Palette.ink.opacity(0.12), lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    private var writeRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.amberDeep)
                .frame(width: 26, height: 26)
            TextField(LocalizedStringKey("Write your own…"), text: $draft)
                .font(Fonts.ui(15, .semibold)).foregroundStyle(Palette.ink)
                .submitLabel(.done)
                .onSubmit(addDraft)
            if !trimmedDraft.isEmpty {
                Button(action: addDraft) {
                    Text("Add").font(Fonts.ui(13.5, .heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Palette.amber, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Palette.ink.opacity(0.12), lineWidth: 1.5))
        .animation(Motion.snappy, value: trimmedDraft.isEmpty)
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
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Palette.ink.opacity(0.12), lineWidth: 1.5))
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
        } else {
            Haptics.select()
            withAnimation(Motion.snappy) { selection.append(line) }
        }
    }

    private func addDraft() {
        let line = trimmedDraft
        draft = ""
        guard !line.isEmpty, !selection.contains(line) else { return }
        Haptics.select()
        withAnimation(Motion.snappy) { selection.append(line) }
    }
}

/// How many lines are in the rotation, against the free cap when there is one.
struct AffirmationCount: View {
    let count: Int
    let isPremium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            (isPremium ? Text("\(count) in your rotation")
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
        ZStack(alignment: .top) {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SoftCircleButton(icon: "chevron.left", iconSize: 15) { dismiss() }
                        .padding(.bottom, 16)

                    Text("Your affirmations").font(Fonts.display(30, .bold)).foregroundStyle(Palette.ink)
                    Text("One shows up each day, in the order you pick them.")
                        .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                    AffirmationCount(count: selection.count, isPremium: premium.isPremium)
                        .padding(.top, 14)

                    AffirmationPicker(selection: $selection, isPremium: premium.isPremium,
                                      onUpsell: { flow.showPaywall() })
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 50)
                .capWidth(Metrics.maxContentWidth)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(.container, edges: .top)
        }
        .onAppear { selection = list.chosen.isEmpty ? Affirmations.defaults : list.chosen }
        .onChange(of: selection) { _, picks in list.set(picks) }
    }
}
