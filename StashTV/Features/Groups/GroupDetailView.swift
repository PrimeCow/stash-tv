import SwiftUI

@MainActor
@Observable
final class GroupDetailViewModel {
    enum Status {
        case idle
        case loading
        case loaded(Group)
        case failed(message: String)
    }

    private(set) var status: Status = .idle

    func load(groupID: String, using config: ServerConfig) async {
        if case .loaded = status { return }
        status = .loading
        do {
            let client = try StashClient.make(from: config)
            let result = try await client.execute(FindGroupQuery(groupID: groupID))
            if let group = result.findGroup {
                status = .loaded(group)
            } else {
                status = .failed(message: "Group not found on server.")
            }
        } catch {
            status = .failed(message: (error as? LocalizedError)?.errorDescription ?? "\(error)")
        }
    }
}

struct GroupDetailView: View {
    let group: Group

    @Environment(ServerConfig.self) private var config
    @State private var viewModel = GroupDetailViewModel()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 60), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 48) {
                header
                content
            }
            .padding(60)
        }
        .navigationTitle(group.displayTitle)
        .task { await viewModel.load(groupID: group.id, using: config) }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 48) {
            if let url = StashURL.authenticated(group.front_image_path, apiKey: config.apiKey) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure, .empty:
                        Color.gray.opacity(0.2)
                    @unknown default: EmptyView()
                    }
                }
                .aspectRatio(2/3, contentMode: .fit)
                .frame(width: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            VStack(alignment: .leading, spacing: 16) {
                Text(group.displayTitle)
                    .font(.largeTitle).bold()
                if let studio = group.studio?.name {
                    Text(studio)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                if let synopsis = group.synopsis, !synopsis.isEmpty {
                    Text(synopsis)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                }
                Spacer(minLength: 0)
                if let scenes = currentScenes, !scenes.isEmpty {
                    NavigationLink(value: ScenePlaylist(
                        scenes: scenes,
                        startIndex: 0,
                        title: group.displayTitle
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
        case .idle, .loading:
            ProgressView("Loading scenes…")
                .frame(maxWidth: .infinity, minHeight: 400)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 400)
        case .loaded(let detailed):
            scenesGrid(scenes: detailed.scenes ?? [])
        }
    }

    private func scenesGrid(scenes: [Scene]) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Scenes")
                .font(.title2).bold()
            if scenes.isEmpty {
                Text("This group has no scenes yet.")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, spacing: 60) {
                    ForEach(Array(scenes.enumerated()), id: \.element.id) { index, scene in
                        NavigationLink(value: ScenePlaylist(
                            scenes: scenes,
                            startIndex: index,
                            title: group.displayTitle
                        )) {
                            SceneCardLabel(scene: scene, apiKey: config.apiKey)
                        }
                        .buttonStyle(.card)
                    }
                }
            }
        }
    }

    private var currentScenes: [Scene]? {
        if case .loaded(let detailed) = viewModel.status { return detailed.scenes }
        return nil
    }
}
