import SwiftUI

struct SceneCardView: View {
    let scene: Scene
    let apiKey: String?

    var body: some View {
        Button {
            // TODO: push player view in a follow-up.
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    Color.gray.opacity(0.2)
                    if let url = authenticatedURL(scene.paths.screenshot) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure, .empty:
                                Image(systemName: "photo")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.secondary)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
                .aspectRatio(16/9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(scene.displayTitle)
                        .font(.headline)
                        .lineLimit(1)
                    if let studio = scene.studio?.name {
                        Text(studio)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .buttonStyle(.card)
    }

    private func authenticatedURL(_ path: String?) -> URL? {
        guard let path, var components = URLComponents(string: path) else { return nil }
        if let apiKey, !apiKey.isEmpty {
            var items = components.queryItems ?? []
            items.append(URLQueryItem(name: "apikey", value: apiKey))
            components.queryItems = items
        }
        return components.url
    }
}
