import SwiftUI

@MainActor
@Observable
final class GroupsBrowseViewModel {
    enum Status {
        case idle
        case loadingInitial
        case loaded
        case failed(message: String)
    }

    private(set) var status: Status = .idle
    private(set) var groups: [Group] = []
    private(set) var totalCount: Int = 0
    private(set) var isLoadingMore = false

    private let perPage: Int
    private let prefetchMargin: Int
    private var currentPage = 0
    private var loadToken = 0

    init(perPage: Int = 40, prefetchMargin: Int = 8) {
        self.perPage = perPage
        self.prefetchMargin = prefetchMargin
    }

    var hasMore: Bool { groups.count < totalCount }

    func loadInitial(using config: ServerConfig) async {
        guard case .idle = status else { return }
        loadToken &+= 1
        let token = loadToken
        currentPage = 0
        groups = []
        totalCount = 0
        status = .loadingInitial
        await loadPage(1, using: config, token: token, isInitial: true)
    }

    func refresh(using config: ServerConfig) async {
        status = .idle
        await loadInitial(using: config)
    }

    func prefetchIfNeeded(currentItem group: Group, using config: ServerConfig) async {
        guard hasMore, !isLoadingMore else { return }
        guard let index = groups.firstIndex(of: group),
              index >= groups.count - prefetchMargin else { return }
        let token = loadToken
        await loadPage(currentPage + 1, using: config, token: token, isInitial: false)
    }

    private func loadPage(_ page: Int, using config: ServerConfig, token: Int, isInitial: Bool) async {
        if !isInitial { isLoadingMore = true }
        defer { if !isInitial { isLoadingMore = false } }
        do {
            let client = try StashClient.make(from: config)
            let result = try await client.execute(FindGroupsQuery(page: page, perPage: perPage))
            guard token == loadToken else { return }
            currentPage = page
            groups.append(contentsOf: result.findGroups.groups)
            totalCount = result.findGroups.count
            status = .loaded
        } catch {
            guard token == loadToken else { return }
            let message = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            if isInitial {
                status = .failed(message: message)
            } else {
                print("[Groups] page \(page) load failed: \(message)")
            }
        }
    }
}

struct GroupsBrowseView: View {
    @Environment(ServerConfig.self) private var config
    @State private var viewModel = GroupsBrowseViewModel()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 80), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    HStack {
                        Text("Groups")
                            .font(.largeTitle).bold()
                        Spacer()
                        SettingsButton()
                    }
                    .focusSection()
                    content
                }
                .padding(60)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Group.self) { group in
                GroupDetailView(group: group)
            }
            .navigationDestination(for: ScenePlaylist.self) { playlist in
                ScenePlayerView(playlist: playlist)
            }
        }
        .task { await viewModel.loadInitial(using: config) }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.status {
        case .idle, .loadingInitial:
            ProgressView("Loading groups…")
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
            if viewModel.groups.isEmpty {
                Text("No groups on this server.")
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
                Text("\(viewModel.groups.count) of \(viewModel.totalCount)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                if viewModel.isLoadingMore {
                    ProgressView()
                }
            }
            LazyVGrid(columns: columns, spacing: 80) {
                ForEach(viewModel.groups) { group in
                    GroupCardView(group: group, apiKey: config.apiKey)
                        .task(id: group.id) {
                            await viewModel.prefetchIfNeeded(currentItem: group, using: config)
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
