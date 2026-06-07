import Foundation

struct FindPerformersQuery: GraphQLOperation {
    typealias Response = Data

    let page: Int
    let perPage: Int
    let sort: String
    let direction: String

    init(page: Int = 1, perPage: Int = 40, sort: String = "name", direction: String = "ASC") {
        self.page = page
        self.perPage = perPage
        self.sort = sort
        self.direction = direction
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
        [
            "filter": AnyEncodable([
                "page": AnyEncodable(page),
                "per_page": AnyEncodable(perPage),
                "sort": AnyEncodable(sort),
                "direction": AnyEncodable(direction),
            ])
        ]
    }

    struct Data: Decodable {
        let findPerformers: FindPerformersResult
    }

    struct FindPerformersResult: Decodable {
        let count: Int
        let performers: [Performer]
    }
}
