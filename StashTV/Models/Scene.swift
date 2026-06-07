import Foundation

struct Scene: Identifiable, Decodable, Hashable {
    let id: String
    let title: String?
    let details: String?
    let date: String?
    let rating100: Int?
    let o_counter: Int?
    let paths: ScenePaths
    let files: [SceneFile]
    let studio: Studio?
    let performers: [Performer]
    let tags: [Tag]

    var displayTitle: String {
        title?.nilIfEmpty
            ?? primaryFile?.basename?.nilIfEmpty.map(Self.stripExtension)
            ?? "Untitled"
    }
    var primaryFile: SceneFile? { files.first }

    private static func stripExtension(_ name: String) -> String {
        (name as NSString).deletingPathExtension
    }
}

struct ScenePaths: Decodable, Hashable {
    let screenshot: String?
    let preview: String?
    let stream: String?
}

struct SceneFile: Decodable, Hashable {
    let basename: String?
    let duration: Double?
    let width: Int?
    let height: Int?
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
