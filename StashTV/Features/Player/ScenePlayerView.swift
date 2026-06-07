import SwiftUI
import AVKit

struct ScenePlayerView: View {
    let scene: Scene

    @Environment(ServerConfig.self) private var config
    @Environment(\.dismiss) private var dismiss

    @State private var player: AVPlayer?
    @State private var loadError: String?

    var body: some View {
        Group {
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
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func prepare() {
        guard player == nil else { return }
        guard let url = StashURL.authenticated(scene.paths.stream, apiKey: config.apiKey) else {
            loadError = "This scene has no stream URL."
            return
        }
        let avPlayer = AVPlayer(url: url)
        avPlayer.automaticallyWaitsToMinimizeStalling = true
        player = avPlayer
        avPlayer.play()
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
