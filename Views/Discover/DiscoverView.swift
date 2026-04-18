import SwiftUI
import SDWebImageSwiftUI

struct DiscoverView: View {
    @Environment(MediaService.self) private var mediaService
    @Environment(SettingsManager.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    @State private var viewModel = DiscoverViewModel()
    @State private var menuHapticTrigger = 0
    @Namespace private var heroNamespace

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    typeSelector
                    discoverContent
                }
            }
            .background(AppTheme.adaptiveBackground(colorScheme))
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { sortButton }
                ToolbarItem(placement: .primaryAction) { filterButton }
            }
            .sheet(item: $viewModel.selectedItem) { item in
                DetailView(item: item)
                    .navigationTransition(.zoom(sourceID: item.id, in: heroNamespace))
            }
            .task {
                if viewModel.discoverMedia.isEmpty {
                    viewModel.loadData(reset: true, mediaService: mediaService)
                }
            }
            .onChange(of: viewModel.selectedMediaType) { _, _ in viewModel.loadData(reset: true, mediaService: mediaService) }
            .onChange(of: viewModel.selectedCatalog) { _, _ in viewModel.loadData(reset: true, mediaService: mediaService) }
            .onChange(of: viewModel.selectedGenre) { _, _ in viewModel.loadData(reset: true, mediaService: mediaService) }
            .onChange(of: settings.animeTitlePreference) { _, _ in
                viewModel.invalidateCache()
                viewModel.loadData(reset: true, mediaService: mediaService)
            }
        }
        .sensoryFeedback(.impact, trigger: viewModel.selectedItem?.id ?? -1)
        .sensoryFeedback(.selection, trigger: menuHapticTrigger)
    }

    // MARK: - Header

    private var typeSelector: some View {
        @Bindable var viewModel = viewModel

        return DiscoverTypeSegmented(selection: Binding(
            get: { viewModel.selectedMediaType },
            set: { viewModel.selectedMediaType = $0 }
        ))
        .frame(maxWidth: .infinity, minHeight: 40)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 20)
    }

    private var sortButton: some View {
        Menu {
            Picker("Sort", selection: Binding(
                get: { viewModel.selectedCatalog },
                set: {
                    viewModel.selectedCatalog = $0
                    menuHapticTrigger += 1
                }
            )) {
                ForEach(DiscoverCatalog.allCases) { catalog in
                    Label(catalog.rawValue, systemImage: catalog.icon)
                        .tag(catalog)
                }
            }
        } label: {
            Image(systemName: viewModel.selectedCatalog.icon)
                .font(.body.weight(.semibold))
        }
        .accessibilityLabel("Sort by")
    }

    private var filterButton: some View {
        Menu {
            Button {
                viewModel.selectedGenre = nil
                menuHapticTrigger += 1
            } label: {
                if viewModel.selectedGenre == nil {
                    Label("All Genres", systemImage: "checkmark")
                } else {
                    Text("All Genres")
                }
            }

            Divider()

            ForEach(viewModel.availableGenres(mediaService: mediaService, settings: settings), id: \.self) { genre in
                Button {
                    viewModel.selectedGenre = genre
                    menuHapticTrigger += 1
                } label: {
                    if viewModel.selectedGenre == genre {
                        Label(genre, systemImage: "checkmark")
                    } else {
                        Text(genre)
                    }
                }
            }
        } label: {
            Image(systemName: viewModel.selectedGenre == nil
                  ? "line.3.horizontal.decrease"
                  : "line.3.horizontal.decrease.circle.fill")
                .font(.body.weight(.semibold))
        }
        .accessibilityLabel("Filter by genre")
    }

    // MARK: - Content

    @ViewBuilder
    private var discoverContent: some View {
        if viewModel.discoverMedia.isEmpty && viewModel.isDiscoverLoading {
            ProgressView("Loading...")
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                .padding(.bottom, 20)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                trendingSection

                if !viewModel.discoverMedia.isEmpty {
                    DiscoverSectionHeader(title: "Browse Catalog")
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)

                    posterGrid(items: viewModel.gridItems())
                } else if !viewModel.isDiscoverLoading {
                    ContentUnavailableView("No Results", systemImage: "magnifyingglass")
                        .padding(.top, 40)
                        .padding(.bottom, 20)
                }
            }
        }
    }

    @ViewBuilder
    private func posterGrid(items: [MediaItem]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(items) { item in
                Button {
                    viewModel.selectedItem = item
                } label: {
                    DiscoverPosterCard(item: item)
                }
                .buttonStyle(.plain)
                .matchedTransitionSource(id: item.id, in: heroNamespace)
            }

            if viewModel.hasMoreDiscover {
                Color.clear
                    .frame(height: 50)
                    .onAppear {
                        viewModel.loadMore(mediaService: mediaService)
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)

        if viewModel.hasMoreDiscover && viewModel.isDiscoverLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private var trendingSection: some View {
        let trendingPreviewItems = viewModel.trendingPreviewItems()
        if !trendingPreviewItems.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                DiscoverSectionHeader(title: viewModel.spotlightTitle)
                    .padding(.horizontal, 16)

                GeometryReader { proxy in
                    let cardWidth = max(280, min(700, proxy.size.width - 56))

                    ScrollView(.horizontal) {
                        HStack(spacing: 14) {
                            ForEach(trendingPreviewItems) { item in
                                Button {
                                    viewModel.selectedItem = item
                                } label: {
                                    FeaturedCardView(item: item)
                                        .frame(width: cardWidth)
                                        .overlay(
                                            Squircle(cornerRadius: 20)
                                                .stroke(.white.opacity(colorScheme == .dark ? 0.16 : 0.24), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                .matchedTransitionSource(id: item.id, in: heroNamespace)
                            }
                        }
                    }
                    .contentMargins(.horizontal, 16)
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned)
                }
                .frame(height: 220)
            }
            .padding(.bottom, 28)
        }
    }
}

// MARK: - Type Segmented Pill

private struct DiscoverTypeSegmented: View {
    @Binding var selection: MediaType?
    @Environment(\.colorScheme) private var colorScheme

    private struct Option: Identifiable {
        let id: String
        let label: String
        let type: MediaType?
    }

    private let options: [Option] = [
        .init(id: "all", label: "All", type: nil),
        .init(id: "movie", label: "Movies", type: .movie),
        .init(id: "tv", label: "TV", type: .tvShow),
        .init(id: "anime", label: "Anime", type: .anime)
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                Button {
                    if selection != option.type {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            selection = option.type
                        }
                    }
                } label: {
                    Text(option.label)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(isSelected(option) ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if isSelected(option) {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .matchedGeometryEffect(id: "segmented.selection", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .liquidGlassCapsule()
        .sensoryFeedback(.selection, trigger: selection)
    }

    @Namespace private var namespace

    private func isSelected(_ option: Option) -> Bool {
        selection == option.type
    }
}

// MARK: - Liquid Glass helper

private extension View {
    /// Applies iOS 26 Liquid Glass in a capsule shape, falling back to
    /// `.ultraThinMaterial` on iOS 18-25 so the same call site works everywhere.
    @ViewBuilder
    func liquidGlassCapsule() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: Capsule())
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
        }
    }
}

// MARK: - Section header

struct DiscoverSectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.title2.weight(.bold))
            Spacer()
        }
    }
}

// MARK: - DiscoverPosterCard

struct DiscoverPosterCard: View {
    let item: MediaItem
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [item.accentColor.opacity(0.4), item.accentColor.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                WebImage(url: item.posterURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    if item.posterURL == nil {
                        VStack(spacing: 4) {
                            Image(systemName: item.type.icon)
                                .font(.largeTitle)
                                .foregroundStyle(item.accentColor.opacity(0.7))
                        }
                    } else {
                        Color.gray.opacity(0.2)
                    }
                }
                .transition(.fade(duration: 0.2))
                .allowsHitTesting(false)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                RatingView(item: item, fontSize: 12, starSize: 10)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(8)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(2 / 3, contentMode: .fit)
        .clipShape(Squircle(cornerRadius: 12))
        .overlay(
            Squircle(cornerRadius: 12)
                .stroke(.white.opacity(colorScheme == .dark ? 0.16 : 0.24), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 5, y: 3)
    }
}
