import Foundation

struct ScenePlaylist: Hashable {
    let scenes: [Scene]
    let startIndex: Int
    let title: String?

    init(scenes: [Scene], startIndex: Int = 0, title: String? = nil) {
        self.scenes = scenes
        self.startIndex = max(0, min(startIndex, scenes.count - 1))
        self.title = title
    }

    static func single(_ scene: Scene) -> ScenePlaylist {
        ScenePlaylist(scenes: [scene], startIndex: 0, title: scene.displayTitle)
    }
}
