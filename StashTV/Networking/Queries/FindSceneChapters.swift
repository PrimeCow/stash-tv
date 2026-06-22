import Foundation

/// Fetches the markers belonging to a single scene, for in-player navigation.
struct FindSceneChaptersQuery: GraphQLOperation {
    typealias Response = Data

    let sceneID: String

    let operationName = "FindSceneChapters"

    let query = """
    query FindSceneChapters($id: ID!) {
      findScene(id: $id) {
        scene_markers {
          id
          title
          seconds
          primary_tag { id name }
          tags { id name }
        }
      }
    }
    """

    var variables: [String: AnyEncodable]? {
        ["id": AnyEncodable(sceneID)]
    }

    struct Data: Decodable {
        let findScene: SceneMarkersContainer?
    }

    struct SceneMarkersContainer: Decodable {
        let scene_markers: [SceneChapter]
    }
}
