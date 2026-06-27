import SwiftUI

enum AppTab: Int, CaseIterable {
    case today, journal, settings

    var title: String {
        switch self {
        case .today: return "Today"
        case .journal: return "Journal"
        case .settings: return "Settings"
        }
    }
    var icon: String {
        switch self {
        case .today: return "sunrise.fill"
        case .journal: return "book.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct MainTabView: View {
    @State private var tab: AppTab = .today

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.pageBackground

            Group {
                switch tab {
                case .today:    TodayView()
                case .journal:  JournalView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar(selection: $tab)
                .padding(.horizontal, 40)
                .padding(.bottom, 6)
        }
    }
}

private struct FloatingTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppTab.allCases, id: \.self) { t in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selection = t }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: t.icon)
                            .font(.system(size: 18, weight: .semibold))
                        Text(t.title)
                            .font(AppFont.caption(12))
                    }
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule(style: .continuous)
                            .fill(selection == t ? Theme.inkGhost : .clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(Theme.card)
        .clipShape(Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(Theme.ink, lineWidth: Theme.borderWidth))
        .background(Capsule(style: .continuous).fill(Theme.ink).offset(y: Theme.shadowOffset))
    }
}
