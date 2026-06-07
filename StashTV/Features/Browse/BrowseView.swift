import SwiftUI

@MainActor
@Observable
final class BrowseViewModel {
    enum State {
        case idle
        case loading
        case loaded(scenes: [Scene], total: Int)
        case failed(message: String)
    }

    var state: State = .idle

    func load(using config: ServerConfig) async {
        state = .loading
        do {
            let client = try StashClient.make(from: config)
            let result = try await client.execute(FindScenesQuery(perPage: 40))
            state = .loaded(scenes: result.findScenes.scenes, total: result.findScenes.count)
        } catch {
            state = .failed(message: (error as? LocalizedError)?.errorDescription ?? "\(error)")
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
        .task { await viewModel.load(using: config) }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Loading scenes…")
                .frame(maxWidth: .infinity, minHeight: 600)
        case .failed(let message):
            VStack(spacing: 24) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await viewModel.load(using: config) }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 600)
        case .loaded(let scenes, let total):
            if scenes.isEmpty {
                Text("No scenes found.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 600)
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    Text("\(total) total")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: columns, spacing: 60) {
                        ForEach(scenes) { scene in
                            SceneCardView(scene: scene, apiKey: config.apiKey)
                        }
                    }
                }
            }
        }
    }
}
