import SwiftUI

struct SceneCardView: View {
    let scene: Scene
    let apiKey: String?
    let playlist: ScenePlaylist

    init(scene: Scene, apiKey: String?, playlist: ScenePlaylist? = nil) {
        self.scene = scene
        self.apiKey = apiKey
        self.playlist = playlist ?? ScenePlaylist.single(scene)
    }

    var body: some View {
        NavigationLink(value: playlist) {
            SceneCardLabel(scene: scene, apiKey: apiKey)
        }
        .buttonStyle(.card)
    }
}

struct SceneCardLabel: View {
    let scene: Scene
    let apiKey: String?

    @Environment(SceneStatsStore.self) private var stats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
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

                if effectiveOCount > 0 {
                    OCountBadge(count: effectiveOCount)
                        .padding(12)
                }
            }

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

    private var effectiveOCount: Int {
        stats.oCounter(for: scene.id, fallback: scene.o_counter) ?? 0
    }
}

struct OCountBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "o.circle.fill")
                .font(.subheadline)
            Text("\(count)")
                .font(.subheadline.monospacedDigit())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}
