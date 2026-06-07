import Foundation

struct ScenePlaylist: Hashable {
    let entries: [PlaylistEntry]
    let startIndex: Int
    let title: String?
    let continuation: PlaybackContext

    init(
        entries: [PlaylistEntry],
        startIndex: Int = 0,
        title: String? = nil,
        continuation: PlaybackContext = .oneOff
    ) {
        self.entries = entries
        self.startIndex = max(0, min(startIndex, max(0, entries.count - 1)))
        self.title = title
        self.continuation = continuation
    }

    static func single(_ scene: Scene, startTime: Double? = nil) -> ScenePlaylist {
        ScenePlaylist(
            entries: [PlaylistEntry(scene: scene, startTime: startTime)],
            startIndex: 0,
            title: scene.displayTitle,
            continuation: .oneOff
        )
    }
}

struct PlaylistEntry: Hashable {
    let scene: Scene
    let startTime: Double?
}
