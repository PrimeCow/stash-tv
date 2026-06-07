import Foundation

struct Group: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let aliases: String?
    let duration: Int?
    let date: String?
    let rating100: Int?
    let director: String?
    let synopsis: String?
    let scene_count: Int
    let front_image_path: String?
    let back_image_path: String?
    let studio: Studio?
    let scenes: [Scene]?

    var displayTitle: String { name }
}
