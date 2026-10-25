import SwiftUI

/// An intentional reading space. Swiping does not change the widget or notification schedule.
struct AffirmationReaderScreen: View {
    @Environment(AffirmationList.self) private var list
    @Environment(PremiumManager.self) private var premium
    @Environment(\.dismiss) private var dismiss
    @State private var content: AffirmationReadingContent?
    @State private var page = 0

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    IconTileButton(icon: "chevron.backward", size: 38, iconSize: 15) { dismiss() }
                    Text(loc: "My affirmations")
                        .font(Fonts.ui(15, .bold)).foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    NavigationLink {
                        AffirmationsScreen().toolbar(.hidden, for: .navigationBar)
                    } label: {
                        Text(loc: "Explore")
                            .font(Fonts.ui(14, .bold)).foregroundStyle(Palette.amberDeep)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                if let content, !content.lines.isEmpty {
                    TabView(selection: $page) {
                        ForEach(Array(content.lines.enumerated()), id: \.element) { index, line in
                            GeometryReader { geometry in
                                ScrollView {
                                    VStack(spacing: 32) {
                                        SunMark(size: 60)
                                            .accessibilityHidden(true)
                                        Affirmations.text(line)
                                            .font(Fonts.display(30, .bold))
                                            .foregroundStyle(Palette.ink)
                                            .multilineTextAlignment(.center)
                                            .lineSpacing(6)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: DesignScale.s(350))
                                    }
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 32)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: geometry.size.height)
                                }
                                .scrollIndicators(.hidden)
                                .scrollBounceBehavior(.basedOnSize)
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    HStack(spacing: 28) {
                        IconTileButton(icon: "chevron.backward", size: 38, iconSize: 15) {
                            move(by: -1)
                        }
                        .disabled(page == 0)
                        .opacity(page == 0 ? 0.35 : 1)
                        .accessibilityLabel(Text(loc: "Previous affirmation"))

                        Text("\(page + 1)/\(content.lines.count)")
                            .font(Fonts.ui(13, .semibold))
                            .foregroundStyle(Palette.inkSofter)
                            .monospacedDigit()
                            .frame(minWidth: 52)

                        IconTileButton(icon: "chevron.forward", size: 38, iconSize: 15) {
                            move(by: 1)
                        }
                        .disabled(page == content.lines.count - 1)
                        .opacity(page == content.lines.count - 1 ? 0.35 : 1)
                        .accessibilityLabel(Text(loc: "Next affirmation"))
                    }
                    .padding(.bottom, 24)
                } else {
                    Spacer()
                    SunMark(size: 60).padding(.bottom, 24)
                    Text(loc: "Choose your affirmations")
                        .font(Fonts.display(26, .bold)).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                    Text(loc: "Add words to My affirmations. Your reader, widgets and reminders use that collection.")
                        .font(Fonts.ui(14, .semibold)).foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center).padding(.top, 8)
                    Spacer()
                }
            }
            .capWidth(Metrics.maxContentWidth)
        }
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            // Preserve the current page when returning from Edit. Refresh the reading snapshot
            // so custom words added there become available without changing the daily selection.
            let current = content.flatMap { $0.lines.indices.contains(page) ? $0.lines[page] : nil }
            let updated = AffirmationReadingContent(
                rotation: Affirmations.rotation(from: list.chosen, premium: premium.isPremium),
                today: list.today(premium: premium.isPremium))
            page = current.flatMap { updated.lines.firstIndex(of: $0) } ?? updated.initialIndex
            content = updated
        }
    }

    private func move(by offset: Int) {
        guard let content else { return }
        let next = page + offset
        guard content.lines.indices.contains(next) else { return }
        Haptics.select()
        page = next
    }
}
