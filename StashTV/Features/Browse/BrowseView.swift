import SwiftUI

@MainActor
@Observable
final class BrowseViewModel {
    enum Status {
        case idle
        case loadingInitial
        case loaded
        case failed(message: String)
    }

    private(set) var status: Status = .idle
    private(set) var scenes: [Scene] = []
    private(set) var totalCount: Int = 0
    private(set) var isLoadingMore = false

    private let perPage: Int
    private let prefetchMargin: Int
    private var currentPage = 0
    private var activeFilter: SavedFilter?
    private var loadToken = 0
    private var randomSeed: Int = .random(in: 1...Int.max)

    init(perPage: Int = 40, prefetchMargin: Int = 8) {
        self.perPage = perPage
        self.prefetchMargin = prefetchMargin
    }

    var hasMore: Bool { scenes.count < totalCount }

    func setActiveFilter(_ filter: SavedFilter?, using config: ServerConfig) async {
        loadToken &+= 1
        let token = loadToken
        activeFilter = filter
        randomSeed = .random(in: 1...Int.max)
        currentPage = 0
        scenes = []
        totalCount = 0
        status = .loadingInitial
        await loadPage(1, using: config, token: token, isInitial: true)
    }

    func refresh(using config: ServerConfig) async {
        await setActiveFilter(activeFilter, using: config)
    }

    func prefetchIfNeeded(currentItem scene: Scene, using config: ServerConfig) async {
        guard hasMore, !isLoadingMore else { return }
        guard let index = scenes.firstIndex(of: scene),
              index >= scenes.count - prefetchMargin else { return }
        let token = loadToken
        await loadPage(currentPage + 1, using: config, token: token, isInitial: false)
    }

    private func resolvedSort() -> String {
        let baseSort = activeFilter?.find_filter?.sort ?? "date"
        if baseSort.hasPrefix("random") {
            return "random_\(randomSeed)"
        }
        return baseSort
    }

    func feedDescriptor() -> SceneFeedDescriptor {
        SceneFeedDescriptor(
            sort: resolvedSort(),
            direction: activeFilter?.find_filter?.direction ?? "DESC",
            sceneFilter: activeFilter?.object_filter?.normalizedForCriterionInput(),
            perPage: perPage
        )
    }

    private func loadPage(_ page: Int, using config: ServerConfig, token: Int, isInitial: Bool) async {
        if !isInitial { isLoadingMore = true }
        defer { if !isInitial { isLoadingMore = false } }
        do {
            let client = try StashClient.make(from: config)
            let query = FindScenesQuery(
                page: page,
                perPage: perPage,
                sort: resolvedSort(),
                direction: activeFilter?.find_filter?.direction ?? "DESC",
                sceneFilter: activeFilter?.object_filter?.normalizedForCriterionInput()
            )
            let result = try await client.execute(query)
            guard token == loadToken else { return }
            currentPage = page
            scenes.append(contentsOf: result.findScenes.scenes)
            totalCount = result.findScenes.count
            status = .loaded
        } catch {
            guard token == loadToken else { return }
            let message = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            if isInitial {
                status = .failed(message: message)
            } else {
                print("[Browse] page \(page) load failed: \(message)")
            }
        }
    }
}

struct BrowseView: View {
    @Environment(ServerConfig.self) private var config
    @Environment(FilterPreferences.self) private var prefs

    @State private var viewModel = BrowseViewModel()
    @State private var catalog = FilterCatalog(mode: .scenes)
    @State private var showManageSheet = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 60), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    inlineHeader
                    if !chips.isEmpty {
                        FilterChipBarView(chips: chips, activeID: chipBinding)
                    }
                    content
                }
                .padding(60)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ScenePlaylist.self) { playlist in
                ScenePlayerView(playlist: playlist)
            }
        }
        .task {
            await catalog.loadIfNeeded(using: config)
            ensureValidActiveSelection()
            await viewModel.setActiveFilter(currentFilter(), using: config)
        }
        .onChange(of: prefs.enabledFilterIDs) { _, _ in ensureValidActiveSelection() }
        .onChange(of: prefs.showRecentScenes) { _, _ in ensureValidActiveSelection() }
        .onChange(of: connectionKey) { _, _ in
            Task { await reloadForConnectionChange() }
        }
        .sheet(isPresented: $showManageSheet) {
            ManageFiltersView(mode: .scenes, catalog: catalog, prefs: prefs)
        }
    }

    /// Changes whenever the server URL or API key is edited (e.g. in Settings),
    /// so a connection that initially failed can recover without relaunching.
    private var connectionKey: String {
        "\(config.serverURL?.absoluteString ?? "")|\(config.apiKey ?? "")"
    }

    private func reloadForConnectionChange() async {
        await catalog.refresh(using: config)
        ensureValidActiveSelection()
        await viewModel.setActiveFilter(currentFilter(), using: config)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.status {
        case .idle, .loadingInitial:
            ProgressView("Loading scenes…")
                .frame(maxWidth: .infinity, minHeight: 600)
        case .failed(let message):
            VStack(spacing: 24) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await viewModel.refresh(using: config) }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 600)
            .focusSection()
        case .loaded:
            if chips.isEmpty {
                emptyFiltersPrompt
            } else if viewModel.scenes.isEmpty {
                Text("No scenes match this filter.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 600)
            } else {
                grid
            }
        }
    }

    private var emptyFiltersPrompt: some View {
        VStack(spacing: 24) {
            Text("No filters enabled.")
                .font(.title3)
            Button {
                showManageSheet = true
            } label: {
                Label("Manage Filters", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 600)
    }

    private var grid: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("\(viewModel.scenes.count) of \(viewModel.totalCount)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                if viewModel.isLoadingMore {
                    ProgressView()
                }
            }
            LazyVGrid(columns: columns, spacing: 60) {
                let entries = viewModel.scenes.map { PlaylistEntry(scene: $0, startTime: nil) }
                let descriptor = viewModel.feedDescriptor()
                ForEach(Array(viewModel.scenes.enumerated()), id: \.element.id) { index, scene in
                    SceneCardView(
                        scene: scene,
                        apiKey: config.apiKey,
                        playlist: ScenePlaylist(
                            entries: entries,
                            startIndex: index,
                            continuation: .scenes(descriptor)
                        )
                    )
                    .task(id: scene.id) {
                        await viewModel.prefetchIfNeeded(currentItem: scene, using: config)
                    }
                }
            }
            if viewModel.hasMore {
                HStack(spacing: 16) {
                    ProgressView()
                    Text("Loading more…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
            }
        }
    }

    private var chips: [FilterChipBarView.Chip] {
        var result: [FilterChipBarView.Chip] = []
        if prefs.showRecentScenes {
            result.append(.init(id: FilterPreferences.recentScenesID, title: "Recent Scenes"))
        }
        for filter in catalog.savedFilters where prefs.enabledFilterIDs.contains(filter.id) {
            result.append(.init(id: filter.id, title: filter.name))
        }
        return result
    }

    private var chipBinding: Binding<String?> {
        Binding(
            get: { prefs.activeFilterID },
            set: { newID in
                guard newID != prefs.activeFilterID else { return }
                prefs.activeFilterID = newID
                Task { await viewModel.setActiveFilter(currentFilter(), using: config) }
            }
        )
    }

    private func currentFilter() -> SavedFilter? {
        guard let id = prefs.activeFilterID,
              id != FilterPreferences.recentScenesID
        else { return nil }
        return catalog.savedFilters.first { $0.id == id }
    }

    private var inlineHeader: some View {
        HStack(spacing: 24) {
            Text("StashTV")
                .font(.largeTitle).bold()
            Spacer()
            Button {
                showManageSheet = true
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Filters")
            Button {
                Task { await viewModel.refresh(using: config) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Refresh")
            .disabled(isLoading)
            SettingsButton()
        }
        .focusSection()
    }

    private var isLoading: Bool {
        if case .loadingInitial = viewModel.status { return true }
        return false
    }

    private func ensureValidActiveSelection() {
        let availableIDs = chips.map(\.id)
        if let current = prefs.activeFilterID, availableIDs.contains(current) {
            return
        }
        prefs.activeFilterID = availableIDs.first
    }
}
