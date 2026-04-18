import SwiftUI
import SDWebImageSwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DetailView: View {
    enum EntryAnimationSource {
        case posterCard
        case mediaCard
    }

    let item: MediaItem
    let continueFocusEpisodeKey: EpisodeKey?
    let entryAnimationSource: EntryAnimationSource
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = DetailViewModel()
    @State private var pendingContinueFocusEpisodeKey: EpisodeKey?
    @State private var didRunPosterDropIn = false
    @State private var sheetPresentHapticTrigger = 0
    @State private var sheetDismissHapticTrigger = 0

    init(
        item: MediaItem,
        continueFocusEpisodeKey: EpisodeKey? = nil,
        entryAnimationSource: EntryAnimationSource = .posterCard
    ) {
        self.item = item
        self.continueFocusEpisodeKey = continueFocusEpisodeKey
        self.entryAnimationSource = entryAnimationSource
        _pendingContinueFocusEpisodeKey = State(initialValue: continueFocusEpisodeKey)
    }

    private var currentItem: MediaItem {
        mediaService.allMedia.first(where: { $0.id == item.id }) ?? item
    }

    private var ratingSource: RatingSource {
        if currentItem.isAniListAnime {
            return .aniList
        }
        switch settings.ratingProvider {
        case .imdb:
            return .imdb
        case .tmdb:
            return .tmdb
        }
    }

    private var detailRatingText: String {
        if currentItem.isAniListAnime {
            return currentItem.formattedRating
        }
        if settings.ratingProvider == .imdb {
            if let imdb = currentItem.imdbRating {
                return String(format: "%.1f", imdb)
            }
            if mediaService.isLoadingImdbRating(currentItem.id) {
                return "..."
            }
            return "—"
        }
        return currentItem.formattedRating
    }

    private var episodeCardWidth: CGFloat {
        horizontalSizeClass == .regular ? 420 : 300
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                DetailHeroSection(item: currentItem)
                    .overlay(alignment: .top) {
                        heroPoster
                            .padding(.top, 48)
                    }

                VStack(alignment: .leading, spacing: 28) {
                    DetailTitleSection(
                        item: currentItem,
                        tvDetail: viewModel.tvDetail,
                        detailRatingText: detailRatingText,
                        ratingSource: ratingSource
                    )
                    
                    DetailActionButtons(
                        currentItem: currentItem,
                        hasEpisodesLoaded: viewModel.hasEpisodesLoaded,
                        allEpisodeKeys: viewModel.allEpisodeKeys,
                        totalEpisodesCount: viewModel.totalEpisodesCount
                    )
                    
                    // DetailProgressSection(
                    //     currentItem: currentItem,
                    //     totalEpisodesCount: viewModel.totalEpisodesCount,
                    //     tvDetail: viewModel.tvDetail
                    // )
                    
                    DetailSeasonsSection(
                        currentItem: currentItem,
                        episodeCardWidth: episodeCardWidth,
                        totalEpisodesCount: viewModel.totalEpisodesCount,
                        autoFocusEpisodeKey: $pendingContinueFocusEpisodeKey,
                        seasons: Bindable(viewModel).seasons,
                        isLoadingSeasons: Bindable(viewModel).isLoadingSeasons,
                        fetchError: Bindable(viewModel).fetchError,
                        expandedSeason: Bindable(viewModel).expandedSeason,
                        loadingSeasonNumbers: Bindable(viewModel).loadingSeasonNumbers,
                        onLoadTVDetails: { await viewModel.loadTVDetails(for: currentItem) },
                        onLoadEpisodesForSeason: { viewModel.loadEpisodesForSeason($0, currentItem: currentItem) }
                    )
                    
                    overviewSection
                    genresSection
                }
                .padding(.horizontal, 22)
                .padding(.top, 40)
                .padding(.bottom, 36)
            }
        }
        .overlay(alignment: .topTrailing) {
            closeButton
        }
        .background(AppTheme.adaptiveBackground(colorScheme))
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .onAppear {
            sheetPresentHapticTrigger += 1
            guard entryAnimationSource == .mediaCard else { return }
            didRunPosterDropIn = false
            withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) {
                didRunPosterDropIn = true
            }
        }
        .onDisappear {
            sheetDismissHapticTrigger += 1
        }
        .task {
            await viewModel.loadTVDetails(for: currentItem)
            if let focusEpisode = pendingContinueFocusEpisodeKey,
               viewModel.seasons.contains(where: { $0.seasonNumber == focusEpisode.season }) {
                viewModel.expandedSeason = focusEpisode.season
                viewModel.loadEpisodesForSeason(focusEpisode.season, currentItem: currentItem)
            }
            if settings.ratingProvider == .imdb {
                _ = await mediaService.fetchImdbRatingForItem(currentItem)
            }
        }
        .sensoryFeedback(.impact, trigger: sheetPresentHapticTrigger)
        .sensoryFeedback(.impact, trigger: sheetDismissHapticTrigger)
    }

    private var heroPoster: some View {
        PosterCard(item: currentItem, width: 170, height: 250, cornerRadius: 18)
            .shadow(color: .black.opacity(0.28), radius: 14, y: 7)
            .opacity(entryAnimationSource == .mediaCard ? (didRunPosterDropIn ? 1 : 0) : 1)
            .offset(y: entryAnimationSource == .mediaCard ? (didRunPosterDropIn ? 0 : -120) : 0)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .accessibilityLabel("Close details")
        .padding(.top, 14)
        .padding(.trailing, 16)
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)
            Text(currentItem.overview)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(6)
        }
    }

    private var genresSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Genres")
                .font(.headline)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(currentItem.genres, id: \.self) { genre in
                        Text(genre)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.adaptiveSecondary(colorScheme))
                            .clipShape(Capsule())
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}
