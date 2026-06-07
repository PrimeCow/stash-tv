import SwiftUI

@MainActor
@Observable
final class PerformerScenesViewModel {
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

    private let performerID: String
    private let perPage: Int
    private let prefetchMargin: Int
    private var currentPage = 0
    private var loadToken = 0

    init(performerID: String, perPage: Int = 40, prefetchMargin: Int = 8) {
        self.performerID = performerID
        self.perPage = perPage
        self.prefetchMargin = prefetchMargin
    }

    var hasMore: Bool { scenes.count < totalCount }

    func loadInitial(using config: ServerConfig) async {
        guard case .idle = status else { return }
        loadToken &+= 1
        let token = loadToken
        currentPage = 0
        scenes = []
        totalCount = 0
        status = .loadingInitial
        await loadPage(1, using: config, token: token, isInitial: true)
    }

    func refresh(using config: ServerConfig) async {
        status = .idle
        await loadInitial(using: config)
    }

    func prefetchIfNeeded(currentItem scene: Scene, using config: ServerConfig) async {
        guard hasMore, !isLoadingMore else { return }
        guard let index = scenes.firstIndex(of: scene),
              index >= scenes.count - prefetchMargin else { return }
        let token = loadToken
        await loadPage(currentPage + 1, using: config, token: token, isInitial: false)
    }

    private func loadPage(_ page: Int, using config: ServerConfig, token: Int, isInitial: Bool) async {
        if !isInitial { isLoadingMore = true }
        defer { if !isInitial { isLoadingMore = false } }
        do {
            let client = try StashClient.make(from: config)
            let sceneFilter: JSONValue = .object([
                "performers": .object([
                    "value": .array([.string(performerID)]),
                    "modifier": .string("INCLUDES"),
                ])
            ])
            let query = FindScenesQuery(
                page: page,
                perPage: perPage,
                sort: "date",
                direction: "DESC",
                sceneFilter: sceneFilter
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
                print("[Performer scenes] page \(page) load failed: \(message)")
            }
        }
    }
}

struct PerformerDetailView: View {
    let performer: Performer

    @Environment(ServerConfig.self) private var config
    @State private var viewModel: PerformerScenesViewModel

    init(performer: Performer) {
        self.performer = performer
        self._viewModel = State(initialValue: PerformerScenesViewModel(performerID: performer.id))
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 60), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 48) {
                header
                content
            }
            .padding(60)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.loadInitial(using: config) }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 48) {
            if let url = StashURL.authenticated(performer.image_path, apiKey: config.apiKey) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure, .empty:
                        Color.gray.opacity(0.2)
                    @unknown default: EmptyView()
                    }
                }
                .aspectRatio(2/3, contentMode: .fit)
                .frame(width: 280)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            VStack(alignment: .leading, spacing: 16) {
                Text(performer.name)
                    .font(.largeTitle).bold()
                if let aliases = performer.aliasesText {
                    Text(aliases)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                if !metadataLine.isEmpty {
                    Text(metadataLine)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if let scenes = currentScenes, !scenes.isEmpty {
                    NavigationLink(value: ScenePlaylist(
                        scenes: scenes,
                        startIndex: 0,
                        title: performer.name
                    )) {
                        Label("Play All", systemImage: "play.fill")
                            .font(.title3)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.status {
        case .idle, .loadingInitial:
            ProgressView("Loading scenes…")
                .frame(maxWidth: .infinity, minHeight: 400)
        case .failed(let message):
            VStack(spacing: 24) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await viewModel.refresh(using: config) }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 400)
        case .loaded:
            if viewModel.scenes.isEmpty {
                Text("This performer has no scenes yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 400)
            } else {
                scenesGrid
            }
        }
    }

    private var scenesGrid: some View {
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

    private var currentScenes: [Scene]? {
        viewModel.scenes.isEmpty ? nil : viewModel.scenes
    }

    private var metadataLine: String {
        var parts: [String] = []
        if let gender = performer.gender, !gender.isEmpty { parts.append(gender.capitalized) }
        if let country = performer.country, !country.isEmpty { parts.append(country) }
        if let birthdate = performer.birthdate, !birthdate.isEmpty { parts.append("b. \(birthdate)") }
        if let count = performer.scene_count { parts.append("\(count) scenes") }
        return parts.joined(separator: " · ")
    }
}
