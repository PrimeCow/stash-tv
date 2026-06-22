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
    @State private var chapters: [SceneChapter] = []
    @State private var playerProxy = PlayerProxy()
    @State private var selectedPerformer: Performer?

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
                    onIncrement: increment(sceneID:),
                    chapters: chapters,
                    performers: queue.currentScene?.performers ?? [],
                    playerProxy: playerProxy,
                    onSelectPerformer: { selectedPerformer = $0 }
                )
                .ignoresSafeArea()
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .task(id: queue.currentScene?.id) { await loadChapters() }
        .fullScreenCover(item: $selectedPerformer, onDismiss: { playerProxy.play() }) { performer in
            performerPage(performer)
        }
    }

    @ViewBuilder
    private func performerPage(_ performer: Performer) -> some View {
        NavigationStack {
            PerformerDetailView(performer: performer)
                .navigationDestination(for: Performer.self) { PerformerDetailView(performer: $0) }
                .navigationDestination(for: ScenePlaylist.self) { ScenePlayerView(playlist: $0) }
        }
    }

    private func loadChapters() async {
        guard let sceneID = queue.currentScene?.id else {
            chapters = []
            return
        }
        do {
            let client = try StashClient.make(from: config)
            let result = try await client.execute(FindSceneChaptersQuery(sceneID: sceneID))
            guard queue.currentScene?.id == sceneID else { return }
            chapters = (result.findScene?.scene_markers ?? []).sorted { $0.seconds < $1.seconds }
        } catch {
            print("[Markers] failed to load chapters for scene \(sceneID): \(error)")
            chapters = []
        }
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
    let chapters: [SceneChapter]
    let performers: [Performer]
    let playerProxy: PlayerProxy
    let onSelectPerformer: (Performer) -> Void

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

        playerProxy.play = { [weak coord] in coord?.player?.play() }
        playerProxy.pause = { [weak coord] in coord?.player?.pause() }

        let performersVC = UIHostingController(rootView: makePerformersView())
        performersVC.title = "Performers"
        coord.performersController = performersVC

        let markersVC = UIHostingController(
            rootView: makeMarkersView(onSelect: { [weak coord] seconds in
                coord?.seek(to: seconds)
            })
        )
        markersVC.title = "Markers"
        coord.markersController = markersVC

        let infoVC = UIHostingController(rootView: makeInfoView())
        infoVC.title = "O Counter"
        coord.infoController = infoVC

        vc.customInfoViewControllers = [markersVC, infoVC, performersVC]

        coord.startObservers()
        queuePlayer.play()
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        let coord = context.coordinator
        coord.parent = self
        coord.infoController?.rootView = makeInfoView()
        coord.markersController?.rootView = makeMarkersView(onSelect: { [weak coord] seconds in
            coord?.seek(to: seconds)
        })
        coord.performersController?.rootView = makePerformersView()
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
        var markersController: UIHostingController<MarkersInfoView>?
        var performersController: UIHostingController<PerformersInfoView>?
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

        func seek(to seconds: Double) {
            player?.seek(
                to: CMTime(seconds: seconds, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .positiveInfinity
            )
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

    private func makePerformersView() -> PerformersInfoView {
        PerformersInfoView(
            performers: performers,
            apiKey: apiKey,
            onSelect: { performer in
                playerProxy.pause()
                onSelectPerformer(performer)
            }
        )
    }

    private func makeMarkersView(onSelect: @escaping (Double) -> Void) -> MarkersInfoView {
        MarkersInfoView(
            chapters: chapters,
            sceneTitle: queue.currentScene?.displayTitle ?? "",
            onSelect: onSelect
        )
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

// MARK: - Player control bridge

/// Lets the SwiftUI layer pause/resume the AVQueuePlayer that lives inside the
/// representable's coordinator (e.g. pause when opening a performer over the player).
@MainActor
@Observable
final class PlayerProxy {
    var play: () -> Void = {}
    var pause: () -> Void = {}
}

// MARK: - Performers panel UI

struct PerformersInfoView: View {
    let performers: [Performer]
    let apiKey: String?
    let onSelect: (Performer) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Performers")
                .font(.caption)
                .foregroundStyle(.secondary)
                .tracking(2)

            if performers.isEmpty {
                Text("No performers for this scene.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 24) {
                        ForEach(performers) { performer in
                            Button {
                                onSelect(performer)
                            } label: {
                                performerCard(performer)
                            }
                            .buttonStyle(.card)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .focusSection()
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func performerCard(_ performer: Performer) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Color.gray.opacity(0.2)
                if let url = StashURL.authenticated(performer.image_path, apiKey: apiKey) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        case .failure, .empty:
                            Image(systemName: "person.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary)
                        @unknown default: EmptyView()
                        }
                    }
                }
            }
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(performer.name)
                .font(.headline)
                .lineLimit(1)
                .frame(width: 200)
        }
        .padding(12)
    }
}

// MARK: - Markers panel UI

struct MarkersInfoView: View {
    let chapters: [SceneChapter]
    let sceneTitle: String
    let onSelect: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Markers")
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

            if chapters.isEmpty {
                Text("This scene has no markers.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 24) {
                        ForEach(chapters) { chapter in
                            Button {
                                onSelect(chapter.seconds)
                            } label: {
                                markerCard(chapter)
                            }
                            .buttonStyle(.card)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .focusSection()
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func markerCard(_ chapter: SceneChapter) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(chapter.formattedTimecode)
                .font(.title3.monospacedDigit().weight(.semibold))
            Text(chapter.displayTitle)
                .font(.headline)
                .lineLimit(1)
            if !chapter.subtitleTags.isEmpty {
                Text(chapter.subtitleTags.joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(width: 320, alignment: .leading)
        .padding(20)
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
