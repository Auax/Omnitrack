import SwiftUI
import SDWebImageSwiftUI
import Combine
import Observation

// MARK: - SearchView

struct SearchView: View {
    @Binding var searchText: String

    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isSearching) private var isSearching

    @State private var viewModel = SearchViewModel()
    @Namespace private var heroNamespace

    private var hasQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if hasQuery {
                    resultsContent
                } else {
                    recentsContent
                }
            }
            .padding(.top, 8)
        }
        .background(AppTheme.adaptiveBackground(colorScheme))
        .navigationTitle("Search")
        .scrollDismissesKeyboard(.interactively)
        .sheet(item: $viewModel.selectedItem) { item in
            DetailView(item: item)
                .navigationTransition(.zoom(sourceID: item.id, in: heroNamespace))
        }
        .task {
            viewModel.setupSearchDebounce(mediaService: mediaService)
        }
        .onChange(of: searchText) { _, newValue in
            viewModel.queryChanged(newValue)
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsContent: some View {
        if viewModel.results.isEmpty && viewModel.isLoading {
            ProgressView("Searching...")
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                .padding(.bottom, 20)
        } else if viewModel.results.isEmpty {
            ContentUnavailableView(
                "No Results",
                systemImage: "magnifyingglass",
                description: Text("Try a different search term.")
            )
            .padding(.top, 40)
            .padding(.bottom, 20)
        } else {
            resultsGrid
        }
    }

    private var resultsGrid: some View {
        VStack(spacing: 0) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(viewModel.results) { item in
                    Button {
                        viewModel.recordRecent(item)
                        viewModel.selectedItem = item
                    } label: {
                        DiscoverPosterCard(item: item)
                    }
                    .buttonStyle(.plain)
                    .matchedTransitionSource(id: item.id, in: heroNamespace)
                }

                if viewModel.hasMore {
                    Color.clear
                        .frame(height: 50)
                        .onAppear {
                            viewModel.loadMore(mediaService: mediaService)
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)

            if viewModel.hasMore && viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Recents

    @ViewBuilder
    private var recentsContent: some View {
        if viewModel.recentSearchItems.isEmpty {
            ContentUnavailableView(
                "No Recent Searches",
                systemImage: "clock.arrow.circlepath",
                description: Text("Search for movies, TV shows, and anime to see them here.")
            )
            .padding(.top, 60)
            .padding(.bottom, 20)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Recent")
                        .font(.title2.weight(.bold))
                    Spacer()
                    Button("Clear") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.clearRecents()
                        }
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(viewModel.recentSearchItems) { item in
                        Button {
                            viewModel.selectedItem = item
                        } label: {
                            DiscoverPosterCard(item: item)
                        }
                        .buttonStyle(.plain)
                        .matchedTransitionSource(id: item.id, in: heroNamespace)
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.removeRecent(item)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - SearchViewModel

@MainActor
@Observable
final class SearchViewModel {
    var results: [MediaItem] = []
    var isLoading: Bool = false
    var hasMore: Bool = true
    var selectedItem: MediaItem?
    var recentSearchItems: [MediaItem] = RecentSearchStore.load().map { $0.toMediaItem() }

    private var currentPage: Int = 1
    private var lastQuery: String = ""

    private let searchTextSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()
    private var activeTask: Task<Void, Never>?

    func setupSearchDebounce(mediaService: MediaService) {
        guard cancellables.isEmpty else { return }

        searchTextSubject
            .removeDuplicates()
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                self?.performSearch(query: query, reset: true, mediaService: mediaService)
            }
            .store(in: &cancellables)
    }

    func queryChanged(_ query: String) {
        searchTextSubject.send(query)
    }

    func performSearch(query: String, reset: Bool, mediaService: MediaService) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            activeTask?.cancel()
            activeTask = nil
            results = []
            hasMore = false
            currentPage = 1
            lastQuery = ""
            isLoading = false
            return
        }

        if reset {
            activeTask?.cancel()
            currentPage = 1
            hasMore = true
            results = []
            lastQuery = trimmed
        }

        guard !isLoading, hasMore else { return }
        isLoading = true
        let pageToLoad = currentPage

        activeTask = Task { @MainActor [weak self] in
            defer {
                self?.isLoading = false
                self?.activeTask = nil
            }
            guard let self else { return }

            do {
                let items = try await mediaService.loadDiscover(
                    page: pageToLoad,
                    type: nil,
                    catalog: .popularity,
                    genreId: nil,
                    query: trimmed
                )
                if Task.isCancelled { return }

                if items.isEmpty {
                    hasMore = false
                } else {
                    results.append(contentsOf: items)
                    currentPage += 1
                }
            } catch {
                if Task.isCancelled { return }
                if reset { results = [] }
                hasMore = false
            }
        }
    }

    func loadMore(mediaService: MediaService) {
        guard !isLoading, hasMore, !lastQuery.isEmpty else { return }
        performSearch(query: lastQuery, reset: false, mediaService: mediaService)
    }

    // MARK: - Recent items

    func recordRecent(_ item: MediaItem) {
        RecentSearchStore.add(.init(from: item))
        recentSearchItems = RecentSearchStore.load().map { $0.toMediaItem() }
    }

    func removeRecent(_ item: MediaItem) {
        RecentSearchStore.remove(id: item.id, type: item.type)
        recentSearchItems = RecentSearchStore.load().map { $0.toMediaItem() }
    }

    func clearRecents() {
        RecentSearchStore.clear()
        recentSearchItems = []
    }
}

// MARK: - Recent Search persistence

private struct RecentSearchSnapshot: Codable {
    let id: Int
    let title: String
    let type: String
    let posterPath: String?
    let backdropPath: String?
    let rating: Double
    let year: Int
    let animeRomajiTitle: String?
    let animeEnglishTitle: String?
    let aniListFormat: String?

    init(from item: MediaItem) {
        self.id = item.id
        self.title = item.title
        self.type = item.type.rawValue
        self.posterPath = item.posterPath
        self.backdropPath = item.backdropPath
        self.rating = item.rating
        self.year = item.year
        self.animeRomajiTitle = item.animeRomajiTitle
        self.animeEnglishTitle = item.animeEnglishTitle
        self.aniListFormat = item.aniListFormat?.rawValue
    }

    func toMediaItem() -> MediaItem {
        let resolvedType = MediaType(rawValue: type) ?? .movie
        let resolvedFormat = aniListFormat.flatMap { AniListMediaFormat(rawValue: $0) }

        return MediaItem(
            id: id,
            title: title,
            subtitle: "",
            overview: "",
            type: resolvedType,
            posterPath: posterPath,
            backdropPath: backdropPath,
            rating: rating,
            year: year,
            releaseDateString: nil,
            genres: [],
            totalEpisodes: nil,
            watchedEpisodes: 0,
            totalSeasons: nil,
            isWatched: false,
            isInProgress: false,
            isInQueue: false,
            genreIds: [],
            imdbRating: nil,
            animeRomajiTitle: animeRomajiTitle,
            animeEnglishTitle: animeEnglishTitle,
            aniListFormat: resolvedFormat,
            aniListIds: []
        )
    }
}

private enum RecentSearchStore {
    static let key = "discover.recentSearchItems"
    static let maxCount = 20

    static func load() -> [RecentSearchSnapshot] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([RecentSearchSnapshot].self, from: data)) ?? []
    }

    static func add(_ snapshot: RecentSearchSnapshot) {
        var items = load().filter { !($0.id == snapshot.id && $0.type == snapshot.type) }
        items.insert(snapshot, at: 0)
        if items.count > maxCount {
            items = Array(items.prefix(maxCount))
        }
        save(items)
    }

    static func remove(id: Int, type: MediaType) {
        let items = load().filter { !($0.id == id && $0.type == type.rawValue) }
        save(items)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    private static func save(_ items: [RecentSearchSnapshot]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
