import Foundation

struct SavedFilter: Identifiable, Decodable, Hashable {
    let id: String
    let mode: String
    let name: String
    let find_filter: SavedFindFilter?
    let object_filter: JSONValue?
}

struct SavedFindFilter: Decodable, Hashable {
    let q: String?
    let sort: String?
    let direction: String?
    let per_page: Int?
}
