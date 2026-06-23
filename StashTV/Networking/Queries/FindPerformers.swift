import Foundation

struct FindPerformersQuery: GraphQLOperation {
    typealias Response = Data

    let page: Int
    let perPage: Int
    let sort: String
    let direction: String
    let searchQuery: String?

    init(page: Int = 1, perPage: Int = 40, sort: String = "name", direction: String = "ASC", q: String? = nil) {
        self.page = page
        self.perPage = perPage
        self.sort = sort
        self.direction = direction
        let trimmed = q?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.searchQuery = (trimmed?.isEmpty == false) ? trimmed : nil
    }

    let operationName = "FindPerformers"

    let query = """
    query FindPerformers($filter: FindFilterType) {
      findPerformers(filter: $filter) {
        count
        performers {
          id
          name
          alias_list
          gender
          country
          birthdate
          image_path
          scene_count
        }
      }
    }
    """

    var variables: [String: AnyEncodable]? {
        var filter: [String: AnyEncodable] = [
            "page": AnyEncodable(page),
            "per_page": AnyEncodable(perPage),
            "sort": AnyEncodable(sort),
            "direction": AnyEncodable(direction),
        ]
        if let searchQuery {
            filter["q"] = AnyEncodable(searchQuery)
        }
        return ["filter": AnyEncodable(filter)]
    }

    struct Data: Decodable {
        let findPerformers: FindPerformersResult
    }

    struct FindPerformersResult: Decodable {
        let count: Int
        let performers: [Performer]
    }
}
