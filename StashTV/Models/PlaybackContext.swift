import Foundation

enum PlaybackContext: Hashable {
    case oneOff
    case scenes(SceneFeedDescriptor)
    case markers(MarkerFeedDescriptor)
    case performer(id: String)
}

struct SceneFeedDescriptor: Hashable {
    let sort: String
    let direction: String
    let sceneFilter: JSONValue?
    let perPage: Int
}

struct MarkerFeedDescriptor: Hashable {
    let sort: String
    let direction: String
    let sceneMarkerFilter: JSONValue?
    let perPage: Int
}
