import Foundation

struct FindScenesQuery: GraphQLOperation {
    typealias Response = Data

    let page: Int
    let perPage: Int
    let sort: String
    let direction: String
    let sceneFilter: JSONValue?

    init(
        page: Int = 1,
        perPage: Int = 40,
        sort: String = "date",
        direction: String = "DESC",
        sceneFilter: JSONValue? = nil
    ) {
        self.page = page
        self.perPage = perPage
        self.sort = sort
        self.direction = direction
        self.sceneFilter = sceneFilter
    }

    let operationName = "FindScenes"

    let query = """
    query FindScenes($filter: FindFilterType, $scene_filter: SceneFilterType) {
      findScenes(filter: $filter, scene_filter: $scene_filter) {
        count
        scenes {
          id
          title
          details
          date
          rating100
          o_counter
          paths { screenshot preview stream }
          files { basename duration width height }
          studio { id name image_path }
          performers { id name image_path }
          tags { id name }
        }
      }
    }
    """

    var variables: [String: AnyEncodable]? {
        var values: [String: AnyEncodable] = [
            "filter": AnyEncodable([
                "page": AnyEncodable(page),
                "per_page": AnyEncodable(perPage),
                "sort": AnyEncodable(sort),
                "direction": AnyEncodable(direction),
            ])
        ]
        if let sceneFilter {
            values["scene_filter"] = AnyEncodable(sceneFilter)
        }
        return values
    }

    struct Data: Decodable {
        let findScenes: FindScenesResult
    }

    struct FindScenesResult: Decodable {
        let count: Int
        let scenes: [Scene]
    }
}
