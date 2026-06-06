import Foundation

struct Performer: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let image_path: String?
}
