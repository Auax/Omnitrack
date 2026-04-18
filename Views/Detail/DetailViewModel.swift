import SwiftUI
import Observation

@Observable
final class DetailViewModel {
    var seasons: [Season] = []
    var isLoadingSeasons: Bool = false
    var fetchError: Bool = false
    var expandedSeason: Int?
    var loadingSeasonNumbers: Set<Int> = []
    var tvDetail: TMDBTVDetail?

    private let tmdbService = TMDBService()

    var totalEpisodesCount: Int {
        seasons.reduce(0) { $0 + $1.episodeCount }
    }

    var hasEpisodesLoaded: Bool {
        seasons.contains(where: { $0.episodeCount > 0 })
    }

    var allEpisodeKeys: [String] {
        seasons.flatMap { season in
            season.episodeCount > 0
                ? (1...season.episodeCount).map { "s\(season.seasonNumber)e\($0)" }
                : []
        }
    }

    @MainActor
    func loadTVDetails(for item: MediaItem) async {
        guard item.hasSeasonsAndEpisodes else { return }

        if item.type == .anime && item.id >= MediaService.aniListAnimeIdOffset {
            await loadAniListAnimeDetails(for: item)
            return
        }

        isLoadingSeasons = true
        fetchError = false

        do {
            let detail = try await tmdbService.fetchTVDetail(id: item.tmdbId)
            tvDetail = detail
            if let summaries = detail.seasons {
                let sorted = summaries
                    .filter { $0.seasonNumber > 0 && $0.episodeCount > 0 }
                    .sorted { $0.seasonNumber < $1.seasonNumber }

                seasons = sorted.map { summary in
                    Season(
                        id: summary.id,
                        seasonNumber: summary.seasonNumber,
                        name: summary.name,
                        episodeCount: summary.episodeCount,
                        episodes: []
                    )
                }
            }
        } catch {
            fetchError = true
        }

        isLoadingSeasons = false
    }

    /// Loads episode details for an AniList anime by first trying to resolve
    /// a TMDB ID via the mapping service, then falling back to synthetic episodes.
    @MainActor
    private func loadAniListAnimeDetails(for item: MediaItem) async {
        isLoadingSeasons = true
        fetchError = false

        // Try to find a TMDB ID from the mapping for any of the item's AniList IDs.
        var resolvedTmdbId: Int?
        for anilistId in item.aniListIds {
            if let tmdbId = await AnimeListMappingService.shared.getTMDBId(for: anilistId) {
                resolvedTmdbId = tmdbId
                break
            }
        }

        if let tmdbId = resolvedTmdbId {
            do {
                let detail = try await tmdbService.fetchTVDetail(id: tmdbId)
                tvDetail = detail
                if let summaries = detail.seasons {
                    let sorted = summaries
                        .filter { $0.seasonNumber > 0 && $0.episodeCount > 0 }
                        .sorted { $0.seasonNumber < $1.seasonNumber }

                    seasons = sorted.map { summary in
                        Season(
                            id: summary.id,
                            seasonNumber: summary.seasonNumber,
                            name: summary.name,
                            episodeCount: summary.episodeCount,
                            episodes: []
                        )
                    }
                }

                isLoadingSeasons = false
                return
            } catch {
                // TMDB fetch failed — fall through to synthetic episodes
            }
        }

        // Fallback: generate synthetic episodes from the AniList episode count
        let episodeCount = item.totalEpisodes ?? 0
        let shouldShowEpisodes: Bool
        if item.hidesAniListEpisodeList {
            shouldShowEpisodes = false
        } else if item.aniListFormat == nil {
            shouldShowEpisodes = episodeCount > 1
        } else {
            shouldShowEpisodes = episodeCount > 0
        }
        if shouldShowEpisodes {
            let episodes = (1...episodeCount).map { ep in
                Episode(
                    id: ep,
                    episodeNumber: ep,
                    seasonNumber: 1,
                    name: "",
                    overview: "",
                    stillPath: nil,
                    airDate: nil,
                    runtime: nil,
                    isWatched: false,
                    isInQueue: false
                )
            }
            seasons = [Season(id: 1, seasonNumber: 1, name: "Episodes", episodeCount: episodeCount, episodes: episodes)]
        }
        isLoadingSeasons = false
    }

    func loadEpisodesForSeason(_ seasonNumber: Int, currentItem: MediaItem) {
        // For AniList anime that resolved to TMDB, we use the resolved TMDB ID
        let tmdbId: Int
        if currentItem.isAniListAnime, let detail = tvDetail {
            tmdbId = detail.id
        } else if currentItem.isAniListAnime {
            // No TMDB data — synthetic episodes are already loaded inline
            return
        } else {
            tmdbId = currentItem.tmdbId
        }

        Task { @MainActor in
            guard !loadingSeasonNumbers.contains(seasonNumber) else { return }
            loadingSeasonNumbers.insert(seasonNumber)

            do {
                let seasonDetail = try await tmdbService.fetchSeasonDetail(tvId: tmdbId, seasonNumber: seasonNumber)

                guard !Task.isCancelled else {
                    loadingSeasonNumbers.remove(seasonNumber)
                    return
                }

                let episodes: [Episode] = seasonDetail.episodes.map { ep in
                    Episode(
                        id: ep.id,
                        episodeNumber: ep.episodeNumber,
                        seasonNumber: ep.seasonNumber,
                        name: ep.name,
                        overview: ep.overview,
                        stillPath: ep.stillPath,
                        airDate: ep.airDate,
                        runtime: ep.runtime,
                        isWatched: false,
                        isInQueue: false
                    )
                }

                if let index = seasons.firstIndex(where: { $0.seasonNumber == seasonNumber }) {
                    seasons[index].episodes = episodes
                }
            } catch {
                if !Task.isCancelled {
                    fetchError = true
                }
            }

            loadingSeasonNumbers.remove(seasonNumber)
        }
    }
}
