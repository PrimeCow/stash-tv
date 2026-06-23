import SwiftUI

@MainActor
@Observable
final class PerformerPickerViewModel {
    enum Status {
        case idle
        case loading
        case loaded
        case failed(message: String)
    }

    private(set) var status: Status = .idle
    private(set) var performers: [Performer] = []
    private(set) var totalCount: Int = 0
    private(set) var isLoadingMore = false

    private let perPage = 40
    private let prefetchMargin = 8
    private var currentPage = 0
    private var loadToken = 0
    private(set) var query = ""

    var hasMore: Bool { performers.count < totalCount }

    func search(_ text: String, using config: ServerConfig) async {
        query = text
        loadToken &+= 1
        let token = loadToken
        currentPage = 0
        performers = []
        totalCount = 0
        status = .loading
        await loadPage(1, using: config, token: token)
    }

    func loadInitialIfNeeded(using config: ServerConfig) async {
        guard case .idle = status else { return }
        await search("", using: config)
    }

    func prefetchIfNeeded(currentItem performer: Performer, using config: ServerConfig) async {
        guard hasMore, !isLoadingMore else { return }
        guard let index = performers.firstIndex(of: performer),
              index >= performers.count - prefetchMargin else { return }
        await loadPage(currentPage + 1, using: config, token: loadToken)
    }

    private func loadPage(_ page: Int, using config: ServerConfig, token: Int) async {
        let isInitial = page == 1
        if !isInitial { isLoadingMore = true }
        defer { if !isInitial { isLoadingMore = false } }
        do {
            let client = try StashClient.make(from: config)
            let result = try await client.execute(
                FindPerformersQuery(page: page, perPage: perPage, q: query)
            )
            guard token == loadToken else { return }
            currentPage = page
            performers.append(contentsOf: result.findPerformers.performers)
            totalCount = result.findPerformers.count
            status = .loaded
        } catch {
            guard token == loadToken else { return }
            let message = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            if isInitial { status = .failed(message: message) }
        }
    }
}

struct PerformerPickerView: View {
    let excludedIDs: Set<String>
    let onPick: (Performer) -> Void

    @Environment(ServerConfig.self) private var config
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = PerformerPickerViewModel()
    @State private var searchText = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 60), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                HStack {
                    Text("Add Performer")
                        .font(.largeTitle).bold()
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(.bordered)
                }
                .focusSection()

                TextField("Search performers", text: $searchText)
                    .font(.title3)
                    .onSubmit {
                        Task { await viewModel.search(searchText, using: config) }
                    }

                content
            }
            .padding(60)
        }
        .background(Color.black.ignoresSafeArea())
        .task { await viewModel.loadInitialIfNeeded(using: config) }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.status {
        case .idle, .loading:
            ProgressView("Loading performers…")
                .frame(maxWidth: .infinity, minHeight: 500)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 500)
        case .loaded:
            if visiblePerformers.isEmpty {
                Text(viewModel.query.isEmpty ? "No performers found." : "No matches for “\(viewModel.query)”.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 500)
            } else {
                grid
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 60) {
            ForEach(visiblePerformers) { performer in
                Button {
                    onPick(performer)
                    dismiss()
                } label: {
                    card(performer)
                }
                .buttonStyle(.card)
                .task(id: performer.id) {
                    await viewModel.prefetchIfNeeded(currentItem: performer, using: config)
                }
            }
        }
    }

    private var visiblePerformers: [Performer] {
        viewModel.performers.filter { !excludedIDs.contains($0.id) }
    }

    private func card(_ performer: Performer) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Color.gray.opacity(0.2)
                if let url = StashURL.authenticated(performer.image_path, apiKey: config.apiKey) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        case .failure, .empty:
                            Image(systemName: "person.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary)
                        @unknown default: EmptyView()
                        }
                    }
                }
            }
            .aspectRatio(2/3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(performer.name)
                .font(.headline)
                .lineLimit(1)
        }
        .padding(12)
    }
}
