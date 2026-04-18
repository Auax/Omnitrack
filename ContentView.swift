import SwiftUI

enum AppTab: Hashable {
    case home
    case discover
    case library
    case search
}

/// Asset Catalog names for tab bar glyphs. Each imageset provides a default (light) asset
/// and a second asset with `luminosity: dark` so the tab bar picks the right artwork per theme.
private enum TabBarCustomIcon: String {
    case home = "home_icon"
    case library = "library_icon"
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: AppTab = .home
    @State private var searchText: String = ""
    @State private var tabChangeHapticTrigger = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView(onExplore: {
                    selectedTab = .discover
                })
            }

            Tab("Discover", systemImage: "safari", value: AppTab.discover) {
                DiscoverView()
            }

            Tab("Library", systemImage: "books.vertical.fill", value: AppTab.library) {
                LibraryView()
            }

            Tab("Search", systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
                NavigationStack {
                    SearchView(searchText: $searchText)
                        .searchable(text: $searchText)
                }
            }
        }
        .tint(colorScheme == .dark ? .white : .primary)
        .sensoryFeedback(.selection, trigger: tabChangeHapticTrigger)
        .onChange(of: selectedTab) { _, _ in
            tabChangeHapticTrigger += 1
        }
    }
}
