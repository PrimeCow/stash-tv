import Foundation

struct Performer: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let image_path: String?
    let alias_list: [String]?
    let gender: String?
    let country: String?
    let birthdate: String?
    let scene_count: Int?

    var aliasesText: String? {
        guard let alias_list, !alias_list.isEmpty else { return nil }
        return alias_list.joined(separator: ", ")
    }
}
