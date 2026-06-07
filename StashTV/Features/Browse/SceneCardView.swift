import SwiftUI

struct SceneCardView: View {
    let scene: Scene
    let apiKey: String?

    var body: some View {
        NavigationLink(value: ScenePlaylist.single(scene)) {
            SceneCardLabel(scene: scene, apiKey: apiKey)
        }
        .buttonStyle(.card)
    }
}

struct SceneCardLabel: View {
    let scene: Scene
    let apiKey: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Color.gray.opacity(0.2)
                if let url = StashURL.authenticated(scene.paths.screenshot, apiKey: apiKey) {
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

            VStack(alignment: .leading, spacing: 6) {
                Text(scene.displayTitle)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if !scene.tags.isEmpty {
                    Text(scene.tags.map(\.name).joined(separator: ", "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }
}
