import SwiftUI
import AVKit

struct ScenePlayerView: View {
    let playlist: ScenePlaylist

    @Environment(ServerConfig.self) private var config
    @Environment(\.dismiss) private var dismiss

    @State private var player: AVQueuePlayer?
    @State private var loadError: String?

    var body: some View {
        SwiftUI.Group {
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else if let loadError {
                errorView(loadError)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.ignoresSafeArea())
            }
        }
        .onAppear(perform: prepare)
        .onDisappear(perform: teardown)
    }

    private func prepare() {
        guard player == nil else { return }
        let items = playlist.scenes
            .dropFirst(playlist.startIndex)
            .compactMap { scene -> AVPlayerItem? in
                guard let url = StashURL.authenticated(scene.paths.stream, apiKey: config.apiKey) else {
                    return nil
                }
                return AVPlayerItem(url: url)
            }
        guard !items.isEmpty else {
            loadError = "No playable streams in this list."
            return
        }
        let queuePlayer = AVQueuePlayer(items: Array(items))
        queuePlayer.automaticallyWaitsToMinimizeStalling = true
        player = queuePlayer
        queuePlayer.play()
    }

    private func teardown() {
        player?.pause()
        player?.removeAllItems()
        player = nil
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Button("Back") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}
