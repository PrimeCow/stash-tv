import Foundation

struct FindGroupsQuery: GraphQLOperation {
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

    let operationName = "FindGroups"

    let query = """
    query FindGroups($filter: FindFilterType) {
      findGroups(filter: $filter) {
        count
        groups {
          id
          name
          aliases
          duration
          date
          rating100
          director
          synopsis
          scene_count
          front_image_path
          back_image_path
          studio { id name image_path }
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
        let findGroups: FindGroupsResult
    }

    struct FindGroupsResult: Decodable {
        let count: Int
        let groups: [Group]
    }
}
