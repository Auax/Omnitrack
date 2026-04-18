import SwiftUI
import SDWebImageSwiftUI

struct LibraryView: View {
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    @Environment(LibraryViewModel.self) private var viewModel
    @State private var continueFocusEpisodeKey: EpisodeKey?
    @State private var selectedEntryAnimationSource: DetailView.EntryAnimationSource = .mediaCard
    @State private var showSettings: Bool = false
    @State private var actionHapticTrigger = 0

    private var continueWatchingItems: [MediaItem] {
        mediaService.inProgressItemsSortedByRecentUpdate()
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel
        NavigationStack {
            ZStack {
                AppTheme.adaptiveBackground(colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        if !continueWatchingItems.isEmpty {
                            continueWatchingSection
                        }

                        LibraryMediaCategorySection(title: "Movies", type: .movie, onTileTapped: { actionHapticTrigger += 1 })
                        LibraryMediaCategorySection(title: "Shows", type: .tvShow, onTileTapped: { actionHapticTrigger += 1 })
                        LibraryMediaCategorySection(title: "Animes", type: .anime, onTileTapped: { actionHapticTrigger += 1 })
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    await mediaService.loadContent(
                        showMovies: settings.showMovies,
                        showTVShows: settings.showTVShows,
                        showAnime: settings.showAnime
                    )
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                        actionHapticTrigger += 1
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .accessibilityLabel("Open Settings")
                }
            }
            .navigationDestination(for: LibraryCollectionRoute.self) { route in
                LibraryCollectionPage(route: route)
            }
            .navigationDestination(isPresented: $bindableViewModel.showingContinueWatchingPage) {
                continueWatchingPage
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(item: $bindableViewModel.selectedItem, onDismiss: {
                continueFocusEpisodeKey = nil
            }) { item in
                DetailView(
                    item: item,
                    continueFocusEpisodeKey: continueFocusEpisodeKey,
                    entryAnimationSource: selectedEntryAnimationSource
                )
            }
            .onChange(of: continueWatchingItems.map(\.id)) { _, _ in
                viewModel.trimContinuePreviewCache(validItems: continueWatchingItems)
                Task {
                    await viewModel.refreshContinueData(for: continueWatchingItems, mediaService: mediaService)
                }
            }
            .task {
                if mediaService.allMedia.isEmpty {
                    await mediaService.loadContent(
                        showMovies: settings.showMovies,
                        showTVShows: settings.showTVShows,
                        showAnime: settings.showAnime
                    )
                }
                viewModel.trimContinuePreviewCache(validItems: continueWatchingItems)
                await viewModel.refreshContinueData(for: continueWatchingItems, mediaService: mediaService)
            }
            .sensoryFeedback(.impact, trigger: actionHapticTrigger)
        }
    }

    private var continueWatchingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                viewModel.showingContinueWatchingPage = true
                actionHapticTrigger += 1
            } label: {
                HStack(spacing: 6) {
                    Text("Continue Watching")
                        .font(.title2.weight(.bold))

                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Text("Pick up where you left off")
                .font(.body.weight(.regular))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
                .padding(.bottom, 10)

            GeometryReader { proxy in
                let cardWidth = max(280, min(700, proxy.size.width - 56))

                ScrollView(.horizontal) {
                    HStack(spacing: 14) {
                        ForEach(continueWatchingItems) { item in
                            LibraryContinueWatchingCardBuilder(
                                item: item,
                                cardWidth: cardWidth,
                                continueFocusEpisodeKey: $continueFocusEpisodeKey,
                                selectedEntryAnimationSource: $selectedEntryAnimationSource
                            )
                        }
                    }
                }
                .contentMargins(.horizontal, 16)
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
            }
            .padding(.horizontal, -16)
            .frame(height: 246)
        }
    }



    private var continueWatchingPage: some View {
        ZStack {
            AppTheme.adaptiveBackground(colorScheme)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if continueWatchingItems.isEmpty {
                        ContentUnavailableView(
                            "No Episodes in Progress",
                            systemImage: "play.circle",
                            description: Text("Start watching a show or anime and it will appear here.")
                        )
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.top, 90)
                    } else {
                        ForEach(continueWatchingItems) { item in
                            LibraryContinueWatchingRowBuilder(
                                item: item
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                LibraryToolbarCircleButton(symbol: "chevron.left") {
                    viewModel.showingContinueWatchingPage = false
                    actionHapticTrigger += 1
                }
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("Continue Watching")
                        .font(.headline)
                    Text("Episodes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }





    private func previewItemsForCategoryTile(type: MediaType, kind: LibraryCollectionKind, fallbackItems: [MediaItem]) -> [MediaItem] {
        let recent: [MediaItem]
        switch kind {
        case .watchlist:
            recent = mediaService.recentQueueItems(type: type, limit: 2)
        case .watched:
            recent = mediaService.recentWatchedItems(type: type, limit: 2)
        }

        if recent.count >= 2 { return recent }

        let seenIds = Set(recent.map(\.id))
        let remainder = fallbackItems.reversed().filter { !seenIds.contains($0.id) }
        return Array((recent + remainder).prefix(2))
    }

    private func watchlistItems(for type: MediaType) -> [MediaItem] {
        mediaService.queueItemsSortedByRecentAddition(type: type)
    }

    private func watchedItems(for type: MediaType) -> [MediaItem] {
        mediaService.watchedItemsSortedByRecentAddition(type: type)
    }
}

private struct LibraryContinueWatchingCardBuilder: View {
    let item: MediaItem
    let cardWidth: CGFloat
    @Environment(LibraryViewModel.self) private var viewModel
    @Binding var continueFocusEpisodeKey: EpisodeKey?
    @Binding var selectedEntryAnimationSource: DetailView.EntryAnimationSource
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        let preview = viewModel.previewForCard(item, mediaService: mediaService)
        let seriesTitle = item.preferredDisplayTitle(animeTitlePreference: settings.animeTitlePreference)
        let stateKey = viewModel.continuePreviewStateKey(for: item, mediaService: mediaService)
        let continueTarget = viewModel.continueTarget(for: item, mediaService: mediaService)
        let previewKey = "\(stateKey)|\(continueTarget?.episode.rawValue ?? "none")|\(continueTarget?.totalEpisodes ?? 0)"
        let cardMetaLine = preview.isLastEpisode
            ? (preview.metaLine.isEmpty ? "Last episode" : "\(preview.metaLine) • Last episode")
            : preview.metaLine

        ContinueWatchingCard(
            item: item,
            cardWidth: cardWidth,
            preview: preview,
            seriesTitle: seriesTitle,
            cardMetaLine: cardMetaLine,
            previewKey: previewKey,
            onSelect: {
                continueFocusEpisodeKey = continueTarget?.episode
                selectedEntryAnimationSource = .mediaCard
                viewModel.selectedItem = item
            },
            onTask: {
                await viewModel.loadContinueTargetIfNeeded(for: item, stateKey: stateKey, mediaService: mediaService)
                await viewModel.loadContinuePreviewIfNeeded(for: item, previewKey: previewKey, mediaService: mediaService)
            }
        )
    }
}

private struct LibraryContinueWatchingRowBuilder: View {
    let item: MediaItem
    @Environment(LibraryViewModel.self) private var viewModel
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        let preview = viewModel.previewForCard(item, mediaService: mediaService)
        let stateKey = viewModel.continuePreviewStateKey(for: item, mediaService: mediaService)
        let seriesTitle = item.preferredDisplayTitle(animeTitlePreference: settings.animeTitlePreference)
        let target = viewModel.continueTarget(for: item, mediaService: mediaService)
        let previewKey = "\(stateKey)|\(target?.episode.rawValue ?? "none")|\(target?.totalEpisodes ?? 0)"
        let nextKey = target?.episode
        let isMarking = viewModel.isMarkingContinueToken(item, target: target)

        ContinueWatchingRow(
            item: item,
            seriesTitle: seriesTitle,
            preview: preview,
            previewKey: previewKey,
            nextKey: nextKey,
            isMarking: isMarking,
            onMarkWatched: {
                viewModel.markContinueEpisodeWatched(item: item, target: target, mediaService: mediaService)
            },
            onTask: {
                await viewModel.loadContinueTargetIfNeeded(for: item, stateKey: stateKey, mediaService: mediaService)
                await viewModel.loadContinuePreviewIfNeeded(for: item, previewKey: previewKey, mediaService: mediaService)
            }
        )
    }
}

private struct LibraryMediaCategorySection: View {
    let title: String
    let type: MediaType
    let onTileTapped: () -> Void
    @Environment(MediaService.self) private var mediaService

    var body: some View {
        let queued = watchlistItems(for: type)
        let watched = watchedItems(for: type)

        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.title2.weight(.bold))
                .lineLimit(1)

            HStack(spacing: 12) {
                LibraryCategoryTile(
                    title: LibraryCollectionKind.watchlist.title,
                    count: queued.count,
                    icon: type.icon,
                    type: type,
                    kind: .watchlist,
                    previewItems: previewItemsForCategoryTile(type: type, kind: .watchlist, fallbackItems: queued),
                    onTap: onTileTapped
                )
                LibraryCategoryTile(
                    title: LibraryCollectionKind.watched.title,
                    count: watched.count,
                    icon: type.icon,
                    type: type,
                    kind: .watched,
                    previewItems: previewItemsForCategoryTile(type: type, kind: .watched, fallbackItems: watched),
                    onTap: onTileTapped
                )
            }
            .padding(.top, 14)
        }
    }

    private func previewItemsForCategoryTile(type: MediaType, kind: LibraryCollectionKind, fallbackItems: [MediaItem]) -> [MediaItem] {
        let recent: [MediaItem]
        switch kind {
        case .watchlist:
            recent = mediaService.recentQueueItems(type: type, limit: 2)
        case .watched:
            recent = mediaService.recentWatchedItems(type: type, limit: 2)
        }

        if recent.count >= 2 { return recent }

        let seenIds = Set(recent.map(\.id))
        let remainder = fallbackItems.reversed().filter { !seenIds.contains($0.id) }
        return Array((recent + remainder).prefix(2))
    }

    private func watchlistItems(for type: MediaType) -> [MediaItem] {
        mediaService.queueItemsSortedByRecentAddition(type: type)
    }

    private func watchedItems(for type: MediaType) -> [MediaItem] {
        mediaService.watchedItemsSortedByRecentAddition(type: type)
    }
}

private struct LibraryToolbarCircleButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
    }
}
