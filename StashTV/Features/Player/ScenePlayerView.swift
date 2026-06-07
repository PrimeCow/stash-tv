import SwiftUI
import AVKit
import UIKit

struct ScenePlayerView: View {
    let playlist: ScenePlaylist

    @Environment(ServerConfig.self) private var config
    @Environment(SceneStatsStore.self) private var stats
    @Environment(\.dismiss) private var dismiss

    @State private var queue: PlaybackQueue
    @State private var isIncrementing = false

    init(playlist: ScenePlaylist) {
        self.playlist = playlist
        self._queue = State(
            initialValue: PlaybackQueue(
                entries: playlist.entries,
                currentEntryIndex: playlist.startIndex
            )
        )
    }

    var body: some View {
        SwiftUI.Group {
            if !hasPlayableItem {
                errorView("No playable streams in this list.")
            } else {
                TVPlayerRepresentable(
                    queue: queue,
                    continuation: playlist.continuation,
                    apiKey: config.apiKey,
                    serverConfig: config,
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
        playlist.entries
            .dropFirst(playlist.startIndex)
            .contains { entry in
                StashURL.authenticated(entry.scene.paths.stream, apiKey: config.apiKey) != nil
            }
    }

    private var currentOCount: Int {
        guard let scene = queue.currentScene else { return 0 }
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
    let queue: PlaybackQueue
    let continuation: PlaybackContext
    let apiKey: String?
    let serverConfig: ServerConfig
    let currentOCount: Int
    let isIncrementing: Bool
    let onIncrement: (String) async -> Void

    private static let topUpThreshold = 3

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        let coord = context.coordinator
        coord.parent = self
        coord.queue = queue
        coord.continuation = continuation
        coord.apiKey = apiKey
        coord.serverConfig = serverConfig

        let initialEntries = Array(queue.entries.dropFirst(queue.currentEntryIndex))
        let items = initialEntries.compactMap { entry -> AVPlayerItem? in
            guard let url = StashURL.authenticated(entry.scene.paths.stream, apiKey: apiKey) else {
                return nil
            }
            return AVPlayerItem(url: url)
        }
        let queuePlayer = AVQueuePlayer(items: Array(items))
        queuePlayer.automaticallyWaitsToMinimizeStalling = true
        coord.player = queuePlayer
        coord.items = items
        coord.entryOffset = queue.currentEntryIndex

        if queue.entries.indices.contains(queue.currentEntryIndex),
           let startTime = queue.entries[queue.currentEntryIndex].startTime,
           startTime > 0 {
            queuePlayer.seek(
                to: CMTime(seconds: startTime, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .positiveInfinity
            )
        }

        vc.player = queuePlayer

        let infoVC = UIHostingController(rootView: makeInfoView())
        infoVC.title = "O Counter"
        vc.customInfoViewControllers = [infoVC]
        coord.infoController = infoVC

        coord.startObservers()
        queuePlayer.play()
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        context.coordinator.parent = self
        context.coordinator.infoController?.rootView = makeInfoView()
    }

    static func dismantleUIViewController(_ vc: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.stopObservers()
        coordinator.player?.pause()
        coordinator.player?.removeAllItems()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator: NSObject {
        var parent: TVPlayerRepresentable?
        var player: AVQueuePlayer?
        var queue: PlaybackQueue?
        var continuation: PlaybackContext = .oneOff
        var apiKey: String?
        var serverConfig: ServerConfig?
        var items: [AVPlayerItem] = []
        var entryOffset: Int = 0
        var infoController: UIHostingController<OCountInfoView>?
        var endObserver: Any?
        var currentItemObservation: NSKeyValueObservation?
        var fetchInProgress: Bool = false

        func startObservers() {
            endObserver = NotificationCenter.default.addObserver(
                forName: AVPlayerItem.didPlayToEndTimeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.maybeFetchMore()
                }
            }
            currentItemObservation = player?.observe(\.currentItem, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in
                    self?.handleCurrentItemChanged()
                }
            }
        }

        func stopObservers() {
            if let observer = endObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            endObserver = nil
            currentItemObservation?.invalidate()
            currentItemObservation = nil
        }

        func handleCurrentItemChanged() {
            guard let player, let currentItem = player.currentItem, let queue else { return }
            guard let itemIndex = items.firstIndex(where: { $0 === currentItem }) else { return }
            let entryIndex = entryOffset + itemIndex
            guard queue.entries.indices.contains(entryIndex) else { return }
            queue.currentEntryIndex = entryIndex

            let entry = queue.entries[entryIndex]
            if let startTime = entry.startTime, startTime > 0 {
                player.seek(
                    to: CMTime(seconds: startTime, preferredTimescale: 600),
                    toleranceBefore: .zero,
                    toleranceAfter: .positiveInfinity
                )
            }
        }

        func maybeFetchMore() async {
            guard !fetchInProgress, let serverConfig, let queue, let player else { return }
            let remaining = player.items().count
            guard remaining < TVPlayerRepresentable.topUpThreshold else { return }
            guard case .oneOff = continuation else {
                // continuable path
                fetchInProgress = true
                defer { fetchInProgress = false }
                let continuator = PlaybackContinuator(config: serverConfig)
                let more = await continuator.fetchMore(
                    context: continuation,
                    alreadyLoaded: queue.entries.count
                )
                guard !more.isEmpty else { return }
                for entry in more {
                    guard let url = StashURL.authenticated(entry.scene.paths.stream, apiKey: apiKey) else { continue }
                    let item = AVPlayerItem(url: url)
                    player.insert(item, after: nil)
                    items.append(item)
                }
                queue.append(more)
                return
            }
        }
    }

    private func makeInfoView() -> OCountInfoView {
        let scene = queue.currentScene
        return OCountInfoView(
            sceneID: scene?.id ?? "",
            sceneTitle: scene?.displayTitle ?? "",
            count: currentOCount,
            isEnabled: scene != nil && !isIncrementing,
            onIncrement: onIncrement
        )
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
