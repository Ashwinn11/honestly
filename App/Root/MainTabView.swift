import SwiftUI

struct MainTabView: View {
    @Environment(AppFlow.self) private var flow

    var body: some View {
        @Bindable var flow = flow
        TabView(selection: $flow.selectedTab) {
            tab(HomeView(),    "Home",    "house",          .home)
            tab(LibraryView(), "Library", "books.vertical", .library)
            tab(ProfileView(), "You",     "person",         .profile)
        }
        .tint(Palette.ink)
    }

    private func tab<Screen: View>(_ screen: Screen, _ title: String,
                                   _ icon: String, _ tag: AppTab) -> some View {
        NavigationStack {
            screen
                .navigationDestination(for: String.self) { key in
                    EntryDetailView(dayKey: key)
                        .toolbar(.hidden, for: .navigationBar)
                }
                .navigationDestination(for: MonthBookRoute.self) { route in
                    EntryDetailView(dayKey: route.startKey, book: route)
                        .toolbar(.hidden, for: .navigationBar)
                }
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: Binding(
                    get: { tag == .home && flow.widgetAffirmationsPresented },
                    set: {
                        guard tag == .home else { return }
                        flow.widgetAffirmationsPresented = $0
                        if !$0 { flow.widgetAffirmationLine = nil }
                    }
                )) {
                    AffirmationReaderScreen(startingLine: flow.widgetAffirmationLine)
                        .toolbar(.hidden, for: .navigationBar)
                }
        }
        .tabItem { Label { Text(loc: title) } icon: { Image(systemName: icon) } }
        .tag(tag)
    }
}
