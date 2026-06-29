import SwiftUI

struct MainTabView: View {
    var body: some View {
        if AppLayout.isPad {
            iPadSidebar
        } else {
            phoneTabs
        }
    }

    // MARK: - iPhone: native bottom tab bar

    private var phoneTabs: some View {
        TabView {
            Tab("Today", systemImage: "sun.max.fill") { TodayView() }
            Tab("Journal", systemImage: "book.fill") {
                // Journal pushes entry details, so it needs a stack; hide the
                // bar so its custom header is the only chrome on iPhone.
                NavigationStack { JournalView().toolbar(.hidden, for: .navigationBar) }
            }
            Tab("Settings", systemImage: "gearshape.fill") { SettingsView() }
        }
    }

    // MARK: - iPad: persistent native sidebar (no top tab bar)

    private var iPadSidebar: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: Binding(
                get: { selection },
                set: { if let v = $0 { selection = v } }
            )) { section in
                NavigationLink(value: section) {
                    Label(section.title, systemImage: section.icon)
                        .font(AppFont.bodySemibold(17))
                }
            }
            .navigationTitle("honestly")
        } detail: {
            switch selection {
            case .today:    TodayView()
            case .journal:
                // Needs a stack for entry pushes; keep the bar visible (inline,
                // no title) so the split view's sidebar toggle still shows.
                NavigationStack { JournalView().navigationBarTitleDisplayMode(.inline) }
            case .settings: SettingsView()
            }
        }
    }

    @State private var selection: AppSection = .today
}

private enum AppSection: String, CaseIterable, Identifiable {
    case today, journal, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .today: "Today"; case .journal: "Journal"; case .settings: "Settings"
        }
    }
    var icon: String {
        switch self {
        case .today: "sun.max.fill"; case .journal: "book.fill"; case .settings: "gearshape.fill"
        }
    }
}
