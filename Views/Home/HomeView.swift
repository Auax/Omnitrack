import SwiftUI

struct HomeView: View {
    let onExplore: () -> Void
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedItem: MediaItem?
    @State private var selectedEntryAnimationSource: DetailView.EntryAnimationSource = .mediaCard
    @State private var hasLoaded: Bool = false
    @State private var actionHapticTrigger = 0
    @Environment(LibraryViewModel.self) private var continueViewModel
    @State private var continueFocusEpisodeKey: EpisodeKey?

    init(onExplore: @escaping () -> Void = {}) {
        self.onExplore = onExplore
    }

    private var enabledTypes: Set<MediaType> {
        var types = Set<MediaType>()
        if settings.showMovies { types.insert(.movie) }
        if settings.showTVShows { types.insert(.tvShow) }
        if settings.showAnime { types.insert(.anime) }
        return types
    }

    private func isTypeEnabled(_ type: MediaType) -> Bool {
        enabledTypes.contains(type)
    }

    private var watchlistItems: [MediaItem] {
        mediaService.queueItemsSortedByRecentAddition()
            .filter { isTypeEnabled($0.type) }
    }

    private var continueWatchingItems: [MediaItem] {
        mediaService.inProgressItemsSortedByRecentUpdate()
            // .filter { item in
            //     guard isTypeEnabled(item.type), item.hasSeasonsAndEpisodes, !item.isWatched else {
            //         return false
            //     }

            //     let watchedCount = mediaService.watchedEpisodeCount(mediaId: item.id)
            //     guard watchedCount > 0 else { return false }

            //     if let total = item.totalEpisodes, total > 0 {
            //         return watchedCount < total
            //     }

            //     return true
            // }
    }

    private var shouldShowInitialLoading: Bool {
        !hasLoaded && mediaService.allMedia.isEmpty && mediaService.errorMessage == nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if (mediaService.isLoading || shouldShowInitialLoading) && mediaService.allMedia.isEmpty {
                        loadingView
                    } else if let error = mediaService.errorMessage, mediaService.allMedia.isEmpty {
                        HomeErrorView(message: error, reloadAction: reloadContent)
                    } else {
                        if !continueWatchingItems.isEmpty {
                            carouselSection(
                                title: "Continue Watching",
                                icon: "play.circle.fill",
                                items: continueWatchingItems,
                                emptyMessage: "No in-progress titles.",
                                showsContinueActions: true
                            )
                        }

                        if watchlistItems.isEmpty {
                            if continueWatchingItems.isEmpty {
                                emptyWatchlistView
                            }
                        } else {
                            carouselSection(
                                title: "Your Watchlist",
                                icon: "bookmark.fill",
                                items: watchlistItems,
                                emptyMessage: "Your watchlist is empty."
                            )
                        }
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .refreshable {
                await mediaService.loadContent(
                    showMovies: settings.showMovies,
                    showTVShows: settings.showTVShows,
                    showAnime: settings.showAnime
                )
            }
            .background(AppTheme.adaptiveBackground(colorScheme))
            .navigationTitle("OmniTrack")
            .sheet(item: $selectedItem, onDismiss: {
                continueFocusEpisodeKey = nil
            }) { item in
                DetailView(
                    item: item,
                    continueFocusEpisodeKey: continueFocusEpisodeKey,
                    entryAnimationSource: selectedEntryAnimationSource
                )
            }
            .task {
                if !hasLoaded {
                    hasLoaded = true
                    await mediaService.loadContent(
                        showMovies: settings.showMovies,
                        showTVShows: settings.showTVShows,
                        showAnime: settings.showAnime
                    )
                }
                continueViewModel.trimContinuePreviewCache(validItems: continueWatchingItems)
                await continueViewModel.refreshContinueData(for: continueWatchingItems, mediaService: mediaService)
            }
            .onChange(of: settings.showMovies) { _, _ in reloadContent() }
            .onChange(of: settings.showTVShows) { _, _ in reloadContent() }
            .onChange(of: settings.showAnime) { _, _ in reloadContent() }
            .onChange(of: settings.animeTitlePreference) { _, _ in reloadContent() }
            .onChange(of: continueWatchingItems.map(\.id)) { _, _ in
                continueViewModel.trimContinuePreviewCache(validItems: continueWatchingItems)
                Task {
                    await continueViewModel.refreshContinueData(for: continueWatchingItems, mediaService: mediaService)
                }
            }
        }
        .sensoryFeedback(.impact, trigger: actionHapticTrigger)
    }

    private func carouselSection(
        title: String,
        icon: String,
        items: [MediaItem],
        emptyMessage: String,
        showsContinueActions: Bool = false,
        emptyActionTitle: String? = nil,
        emptyAction: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: title)
                .padding(.horizontal, 16)

            if items.isEmpty {
                if let emptyActionTitle, let emptyAction {
                    ContentUnavailableView {
                        Label(title, systemImage: icon)
                    } description: {
                        Text(emptyMessage)
                    } actions: {
                        Button(emptyActionTitle) {
                            emptyAction()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ContentUnavailableView(
                        title,
                        systemImage: icon,
                        description: Text(emptyMessage)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                GeometryReader { proxy in
                    let cardWidth = max(280, min(700, proxy.size.width - 56))

                    ScrollView(.horizontal) {
                        HStack(spacing: 14) {
                            ForEach(items.prefix(12)) { item in
                                if showsContinueActions && item.hasSeasonsAndEpisodes {
                                    HomeContinueWatchingCardBuilder(
                                        item: item,
                                        cardWidth: cardWidth,
                                        selectedItem: $selectedItem,
                                        continueFocusEpisodeKey: $continueFocusEpisodeKey,
                                        selectedEntryAnimationSource: $selectedEntryAnimationSource
                                    )
                                } else {
                                    Button {
                                        continueFocusEpisodeKey = nil
                                        selectedEntryAnimationSource = .mediaCard
                                        selectedItem = item
                                        actionHapticTrigger += 1
                                    } label: {
                                        MediaCard(
                                            imageURL: item.backdropURL ?? item.posterURL,
                                            title: item.title,
                                            subtitle: item.subtitle,
                                            cardWidth: cardWidth
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, 16)
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned)
                    .simultaneousGesture(DragGesture(minimumDistance: 0))
                }
                .frame(height: showsContinueActions ? 246 : 220)
            }
        }
    }





    private var emptyWatchlistView: some View {
        ContentUnavailableView {
            Label("Nothing here yet", systemImage: "sparkles")
        } description: {
            Text("Your watchlist is feeling a bit lonely.\nExplore new titles to get started!")
        } actions: {
            Button("Explore") {
                onExplore()
                actionHapticTrigger += 1
            }
            .buttonStyle(.borderedProminent)
            .tint(colorScheme == .dark ? .white : .black)
            .foregroundStyle(colorScheme == .dark ? .black : .white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }



    private func reloadContent() {
        Task {
            await mediaService.loadContent(
                showMovies: settings.showMovies,
                showTVShows: settings.showTVShows,
                showAnime: settings.showAnime
            )
        }
    }
}

private struct HomeContinueWatchingCardBuilder: View {
    let item: MediaItem
    let cardWidth: CGFloat
    @Binding var selectedItem: MediaItem?
    @Binding var continueFocusEpisodeKey: EpisodeKey?
    @Binding var selectedEntryAnimationSource: DetailView.EntryAnimationSource
    @Environment(LibraryViewModel.self) private var viewModel
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        let preview = viewModel.previewForCard(item, mediaService: mediaService)
        let seriesTitle = item.preferredDisplayTitle(animeTitlePreference: settings.animeTitlePreference)
        let stateKey = viewModel.continuePreviewStateKey(for: item, mediaService: mediaService)
        let continueTarget = viewModel.continueTarget(for: item, mediaService: mediaService)
        let previewKey = "\(stateKey)|\(continueTarget?.episode.rawValue ?? "none")|\(continueTarget?.totalEpisodes ?? 0)"

        ContinueWatchingCard(
            item: item,
            cardWidth: cardWidth,
            preview: preview,
            seriesTitle: seriesTitle,
            cardMetaLine: preview.metaLine,
            previewKey: previewKey,
            onSelect: {
                continueFocusEpisodeKey = continueTarget?.episode
                selectedEntryAnimationSource = .mediaCard
                selectedItem = item
            },
            onTask: {
                await viewModel.loadContinueTargetIfNeeded(for: item, stateKey: stateKey, mediaService: mediaService)
                await viewModel.loadContinuePreviewIfNeeded(for: item, previewKey: previewKey, mediaService: mediaService)
            }
        )
    }
}

private struct HomeErrorView: View {
    let message: String
    let reloadAction: () -> Void
    @State private var retryHapticTrigger = 0

    var body: some View {
        ContentUnavailableView {
            Label("Unable to Load", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                reloadAction()
                retryHapticTrigger += 1
            }
        }
        .padding(.top, 40)
        .sensoryFeedback(.impact, trigger: retryHapticTrigger)
    }
}

private struct HomeSectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.title2.weight(.bold))
                
            Spacer()
        }
    }
}
