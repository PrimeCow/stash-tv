import SwiftUI
import AVKit
import UIKit

struct ScenePlayerView: View {
    let playlist: ScenePlaylist

    @Environment(ServerConfig.self) private var config
    @Environment(SceneStatsStore.self) private var stats
    @Environment(\.dismiss) private var dismiss

    @State private var currentSceneIndex: Int
    @State private var isIncrementing = false

    init(playlist: ScenePlaylist) {
        self.playlist = playlist
        self._currentSceneIndex = State(initialValue: playlist.startIndex)
    }

    var body: some View {
        SwiftUI.Group {
            if !hasPlayableItem {
                errorView("No playable streams in this list.")
            } else {
                TVPlayerRepresentable(
                    playlist: playlist,
                    apiKey: config.apiKey,
                    currentSceneIndex: $currentSceneIndex,
                    currentOCount: currentOCount,
                    isIncrementing: isIncrementing,
                    onIncrement: increment(sceneID:)
                )
                .ignoresSafeArea()
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private var hasPlayableItem: Bool {
        playlist.scenes
            .dropFirst(playlist.startIndex)
            .contains { scene in
                StashURL.authenticated(scene.paths.stream, apiKey: config.apiKey) != nil
            }
    }

    private var currentOCount: Int {
        guard currentSceneIndex >= 0, currentSceneIndex < playlist.scenes.count else { return 0 }
        let scene = playlist.scenes[currentSceneIndex]
        return stats.oCounter(for: scene.id, fallback: scene.o_counter) ?? 0
    }

    private func increment(sceneID: String) async {
        guard !isIncrementing else { return }
        isIncrementing = true
        defer { isIncrementing = false }
        do {
            let client = try StashClient.make(from: config)
            let result = try await client.execute(SceneIncrementOMutation(sceneID: sceneID))
            stats.setOCounter(result.sceneIncrementO, for: sceneID)
        } catch {
            print("[OCount] increment failed for scene \(sceneID): \(error)")
        }
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

// MARK: - UIKit player wrapper

struct TVPlayerRepresentable: UIViewControllerRepresentable {
    let playlist: ScenePlaylist
    let apiKey: String?
    @Binding var currentSceneIndex: Int
    let currentOCount: Int
    let isIncrementing: Bool
    let onIncrement: (String) async -> Void

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()

        let items = playlist.scenes
            .dropFirst(playlist.startIndex)
            .compactMap { scene -> AVPlayerItem? in
                guard let url = StashURL.authenticated(scene.paths.stream, apiKey: apiKey) else {
                    return nil
                }
                return AVPlayerItem(url: url)
            }
        let queuePlayer = AVQueuePlayer(items: Array(items))
        queuePlayer.automaticallyWaitsToMinimizeStalling = true
        if let startTime = playlist.startTime, startTime > 0 {
            queuePlayer.seek(
                to: CMTime(seconds: startTime, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .positiveInfinity
            )
        }
        vc.player = queuePlayer
        context.coordinator.player = queuePlayer

        let infoVC = UIHostingController(rootView: makeInfoView())
        infoVC.title = "O Counter"
        vc.customInfoViewControllers = [infoVC]
        context.coordinator.infoController = infoVC

        let observer = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: nil,
            queue: .main
        ) { _ in
            let next = currentSceneIndex + 1
            if next < playlist.scenes.count {
                currentSceneIndex = next
            }
        }
        context.coordinator.endObserver = observer

        queuePlayer.play()
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        context.coordinator.infoController?.rootView = makeInfoView()
    }

    static func dismantleUIViewController(_ vc: AVPlayerViewController, coordinator: Coordinator) {
        if let observer = coordinator.endObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        coordinator.player?.pause()
        coordinator.player?.removeAllItems()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        var endObserver: Any?
        var player: AVQueuePlayer?
        var infoController: UIHostingController<OCountInfoView>?
    }

    private func makeInfoView() -> OCountInfoView {
        let scene = currentScene()
        return OCountInfoView(
            sceneID: scene?.id ?? "",
            sceneTitle: scene?.displayTitle ?? "",
            count: currentOCount,
            isEnabled: scene != nil && !isIncrementing,
            onIncrement: onIncrement
        )
    }

    private func currentScene() -> Scene? {
        guard currentSceneIndex >= 0, currentSceneIndex < playlist.scenes.count else { return nil }
        return playlist.scenes[currentSceneIndex]
    }
}

// MARK: - Custom info panel UI

struct OCountInfoView: View {
    let sceneID: String
    let sceneTitle: String
    let count: Int
    let isEnabled: Bool
    let onIncrement: (String) async -> Void

    var body: some View {
        HStack(spacing: 60) {
            VStack(alignment: .leading, spacing: 8) {
                Text("O Counter")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .tracking(2)
                if !sceneTitle.isEmpty {
                    Text(sceneTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 20) {
                Image(systemName: "o.circle.fill")
                    .font(.system(size: 60))
                Text("\(count)")
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }

            Spacer()

            Button {
                Task { await onIncrement(sceneID) }
            } label: {
                Label("Increment", systemImage: "plus.circle.fill")
                    .font(.title3)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isEnabled)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
