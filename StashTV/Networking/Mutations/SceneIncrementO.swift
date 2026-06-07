import Foundation

struct SceneIncrementOMutation: GraphQLOperation {
    typealias Response = Data

    let sceneID: String

    let operationName = "SceneIncrementO"

    let query = """
    mutation SceneIncrementO($id: ID!) {
      sceneIncrementO(id: $id)
    }
    """

    var variables: [String: AnyEncodable]? {
        ["id": AnyEncodable(sceneID)]
    }

    struct Data: Decodable {
        let sceneIncrementO: Int
    }
}
