import Foundation

/// Replaces a scene's performer list with the given IDs (Stash's `sceneUpdate`
/// sets `performer_ids` wholesale), returning the resulting performers so the
/// client can sync local state.
struct SceneSetPerformersMutation: GraphQLOperation {
    typealias Response = Data

    let sceneID: String
    let performerIDs: [String]

    let operationName = "SceneSetPerformers"

    let query = """
    mutation SceneSetPerformers($id: ID!, $performer_ids: [ID!]) {
      sceneUpdate(input: { id: $id, performer_ids: $performer_ids }) {
        id
        performers { id name image_path }
      }
    }
    """

    var variables: [String: AnyEncodable]? {
        [
            "id": AnyEncodable(sceneID),
            "performer_ids": AnyEncodable(performerIDs),
        ]
    }

    struct Data: Decodable {
        let sceneUpdate: UpdatedScene?
    }

    struct UpdatedScene: Decodable {
        let id: String
        let performers: [Performer]
    }
}
