import SwiftUI

/// The four-tab shell (Home · Calendar · History · You) using the native tab bar, amber-tinted.
/// Selection lives in `AppFlow` so any screen can switch tabs (e.g. Home's "All →" → History).
/// Each tab owns a NavigationStack so entry detail pushes over its own screen; the ritual and
/// paywall present above everything from `RootView`.
struct MainTabView: View {
    @Environment(AppFlow.self) private var flow

    var body: some View {
        @Bindable var flow = flow
        TabView(selection: $flow.selectedTab) {
            tab(HomeView(),     "Home",     "house",    .home)
            tab(CalendarView(), "Calendar", "calendar", .calendar)
            tab(HistoryView(),  "History",  "clock",    .history)
            tab(ProfileView(),  "You",      "person",   .profile)
        }
        .tint(Palette.amber)
    }

    private func tab<Screen: View>(_ screen: Screen, _ title: String,
                                   _ icon: String, _ tag: AppTab) -> some View {
        NavigationStack {
            screen
                .navigationDestination(for: String.self) { key in
                    EntryDetailView(dayKey: key)
                        .toolbar(.hidden, for: .navigationBar)
                }
                .toolbar(.hidden, for: .navigationBar)
        }
        .tabItem { Label(title, systemImage: icon) }
        .tag(tag)
    }
}
