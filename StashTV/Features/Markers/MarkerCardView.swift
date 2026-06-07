import SwiftUI

struct MarkerCardView: View {
    let marker: SceneMarker
    let apiKey: String?
    let playlist: ScenePlaylist

    @Environment(SceneStatsStore.self) private var stats

    init(marker: SceneMarker, apiKey: String?, playlist: ScenePlaylist? = nil) {
        self.marker = marker
        self.apiKey = apiKey
        self.playlist = playlist ?? ScenePlaylist.single(marker.scene, startTime: marker.seconds)
    }

    var body: some View {
        NavigationLink(value: playlist) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topLeading) {
                    ZStack(alignment: .bottomTrailing) {
                        ZStack {
                            Color.gray.opacity(0.2)
                            if let url = imageURL {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                    case .failure, .empty:
                                        Image(systemName: "bookmark.fill")
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

                        Text(marker.formattedTimecode)
                            .font(.footnote.monospacedDigit())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(8)
                    }

                    if effectiveOCount > 0 {
                        OCountBadge(count: effectiveOCount)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(marker.displayTitle)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if !marker.subtitleTags.isEmpty {
                        Text(marker.subtitleTags.joined(separator: ", "))
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
        .buttonStyle(.card)
    }

    private var imageURL: URL? {
        StashURL.authenticated(marker.screenshot ?? marker.scene.paths.screenshot, apiKey: apiKey)
    }

    private var effectiveOCount: Int {
        stats.oCounter(for: marker.scene.id, fallback: marker.scene.o_counter) ?? 0
    }
}
