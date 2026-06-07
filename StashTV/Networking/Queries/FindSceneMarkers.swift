import Foundation

struct FindSceneMarkersQuery: GraphQLOperation {
    typealias Response = Data

    let page: Int
    let perPage: Int
    let sort: String
    let direction: String
    let sceneMarkerFilter: JSONValue?

    init(
        page: Int = 1,
        perPage: Int = 40,
        sort: String = "created_at",
        direction: String = "DESC",
        sceneMarkerFilter: JSONValue? = nil
    ) {
        self.page = page
        self.perPage = perPage
        self.sort = sort
        self.direction = direction
        self.sceneMarkerFilter = sceneMarkerFilter
    }

    let operationName = "FindSceneMarkers"

    let query = """
    query FindSceneMarkers($filter: FindFilterType, $scene_marker_filter: SceneMarkerFilterType) {
      findSceneMarkers(filter: $filter, scene_marker_filter: $scene_marker_filter) {
        count
        scene_markers {
          id
          title
          seconds
          end_seconds
          stream
          preview
          screenshot
          primary_tag { id name }
          tags { id name }
          scene {
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
        if let sceneMarkerFilter {
            values["scene_marker_filter"] = AnyEncodable(sceneMarkerFilter)
        }
        return values
    }

    struct Data: Decodable {
        let findSceneMarkers: FindSceneMarkersResult
    }

    struct FindSceneMarkersResult: Decodable {
        let count: Int
        let scene_markers: [SceneMarker]
    }
}
