import SwiftUI
import Observation

@MainActor
@Observable
final class DiscoverViewModel {
    var selectedMediaType: MediaType? = nil
    var selectedCatalog: DiscoverCatalog = .popularity
    var selectedGenre: String? = nil
    var selectedItem: MediaItem?

    var discoverMedia: [MediaItem] = []
    var isDiscoverLoading: Bool = false
    var hasMoreDiscover: Bool = true
    private var currentDiscoverPage: Int = 1

    private var activeLoadTask: Task<Void, Never>?

    private struct CacheKey: Hashable {
        let mediaType: MediaType?
        let catalog: DiscoverCatalog
        let genre: String?
    }

    private struct CacheEntry {
        var media: [MediaItem]
        var currentPage: Int
        var hasMore: Bool
    }

    private var cache: [CacheKey: CacheEntry] = [:]

    private var currentCacheKey: CacheKey {
        CacheKey(mediaType: selectedMediaType, catalog: selectedCatalog, genre: selectedGenre)
    }

    var spotlightTitle: String {
        switch selectedCatalog {
        case .trending: return "Trending Now"
        case .rating: return "Top Rated"
        case .popularity: return "Popular Now"
        }
    }

    func availableGenres(mediaService: MediaService, settings: SettingsManager) -> [String] {
        mediaService.discoverGenreNames(includeAniListGenres: true)
    }

    func trendingPreviewItems() -> [MediaItem] {
        Array(discoverMedia.prefix(8))
    }

    func gridItems() -> [MediaItem] {
        let trendingCount = trendingPreviewItems().count
        let remainder = Array(discoverMedia.dropFirst(trendingCount))
        return remainder.isEmpty ? discoverMedia : remainder
    }

    func loadData(reset: Bool, mediaService: MediaService) {
        activeLoadTask?.cancel()
        isDiscoverLoading = false

        let key = currentCacheKey

        if reset {
            if let cached = cache[key], !cached.media.isEmpty {
                discoverMedia = cached.media
                currentDiscoverPage = cached.currentPage
                hasMoreDiscover = cached.hasMore
                return
            }

            currentDiscoverPage = 1
            hasMoreDiscover = true
            discoverMedia = []
        }

        guard hasMoreDiscover else { return }

        isDiscoverLoading = true
        let pageToLoad = currentDiscoverPage

        activeLoadTask = Task { @MainActor [weak self] in
            defer {
                self?.isDiscoverLoading = false
                self?.activeLoadTask = nil
            }

            guard let self else { return }
            let genreId = selectedGenre.flatMap { mediaService.genreIdForName($0) }

            do {
                let fetchedItems = try await mediaService.loadDiscover(
                    page: pageToLoad,
                    type: selectedMediaType,
                    catalog: selectedCatalog,
                    genreId: genreId,
                    query: ""
                )

                if Task.isCancelled { return }
                guard key == currentCacheKey else { return }

                if fetchedItems.isEmpty {
                    hasMoreDiscover = false
                } else {
                    discoverMedia.append(contentsOf: fetchedItems)
                    currentDiscoverPage += 1
                }

                cache[key] = CacheEntry(
                    media: discoverMedia,
                    currentPage: currentDiscoverPage,
                    hasMore: hasMoreDiscover
                )
            } catch {
                if Task.isCancelled { return }
                guard key == currentCacheKey else { return }
                if reset { discoverMedia = [] }
                hasMoreDiscover = false
            }
        }
    }

    func loadMore(mediaService: MediaService) {
        guard !isDiscoverLoading, hasMoreDiscover else { return }
        loadData(reset: false, mediaService: mediaService)
    }

    func invalidateCache() {
        cache.removeAll()
    }
}
