import Foundation

struct FindScenesQuery: GraphQLOperation {
    typealias Response = Data

    let page: Int
    let perPage: Int
    let sort: String

    init(page: Int = 1, perPage: Int = 40, sort: String = "date") {
        self.page = page
        self.perPage = perPage
        self.sort = sort
    }

    let operationName = "FindScenes"

    let query = """
    query FindScenes($filter: FindFilterType) {
      findScenes(filter: $filter) {
        count
        scenes {
          id
          title
          details
          date
          rating100
          paths { screenshot preview stream }
          files { duration width height }
          studio { id name image_path }
          performers { id name image_path }
          tags { id name }
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
                "direction": AnyEncodable("DESC"),
            ])
        ]
    }

    struct Data: Decodable {
        let findScenes: FindScenesResult
    }

    struct FindScenesResult: Decodable {
        let count: Int
        let scenes: [Scene]
    }
}
