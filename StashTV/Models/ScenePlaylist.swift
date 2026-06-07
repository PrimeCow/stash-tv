import Foundation

struct ScenePlaylist: Hashable {
    let scenes: [Scene]
    let startIndex: Int
    let startTime: Double?
    let title: String?

    init(
        scenes: [Scene],
        startIndex: Int = 0,
        startTime: Double? = nil,
        title: String? = nil
    ) {
        self.scenes = scenes
        self.startIndex = max(0, min(startIndex, max(0, scenes.count - 1)))
        self.startTime = startTime
        self.title = title
    }

    static func single(_ scene: Scene, startTime: Double? = nil) -> ScenePlaylist {
        ScenePlaylist(scenes: [scene], startIndex: 0, startTime: startTime, title: scene.displayTitle)
    }
}
