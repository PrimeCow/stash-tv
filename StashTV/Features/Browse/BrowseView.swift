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

    init(perPage: Int = 40, prefetchMargin: Int = 8) {
        self.perPage = perPage
        self.prefetchMargin = prefetchMargin
    }

    var hasMore: Bool { scenes.count < totalCount }

    func loadInitial(using config: ServerConfig) async {
        guard case .idle = status else { return }
        status = .loadingInitial
        currentPage = 0
        scenes = []
        totalCount = 0
        await loadPage(1, using: config, isInitial: true)
    }

    func refresh(using config: ServerConfig) async {
        status = .idle
        await loadInitial(using: config)
    }

    func prefetchIfNeeded(currentItem scene: Scene, using config: ServerConfig) async {
        guard hasMore, !isLoadingMore else { return }
        guard let index = scenes.firstIndex(of: scene),
              index >= scenes.count - prefetchMargin else { return }
        await loadPage(currentPage + 1, using: config, isInitial: false)
    }

    private func loadPage(_ page: Int, using config: ServerConfig, isInitial: Bool) async {
        if !isInitial { isLoadingMore = true }
        defer { if !isInitial { isLoadingMore = false } }
        do {
            let client = try StashClient.make(from: config)
            let result = try await client.execute(FindScenesQuery(page: page, perPage: perPage))
            currentPage = page
            scenes.append(contentsOf: result.findScenes.scenes)
            totalCount = result.findScenes.count
            status = .loaded
        } catch {
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
    @State private var viewModel = BrowseViewModel()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 60), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .padding(60)
            }
            .navigationTitle("Recent Scenes")
            .navigationDestination(for: Scene.self) { scene in
                ScenePlayerView(scene: scene)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out", role: .destructive) {
                        config.serverURL = nil
                        config.apiKey = nil
                    }
                }
            }
        }
        .task { await viewModel.loadInitial(using: config) }
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
        case .loaded:
            if viewModel.scenes.isEmpty {
                Text("No scenes found.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 600)
            } else {
                grid
            }
        }
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
                ForEach(viewModel.scenes) { scene in
                    SceneCardView(scene: scene, apiKey: config.apiKey)
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
}
