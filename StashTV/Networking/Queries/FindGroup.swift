import Foundation

struct FindGroupQuery: GraphQLOperation {
    typealias Response = Data

    let groupID: String

    let operationName = "FindGroup"

    let query = """
    query FindGroup($id: ID!) {
      findGroup(id: $id) {
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
        scenes {
          id
          title
          details
          date
          rating100
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
        ["id": AnyEncodable(groupID)]
    }

    struct Data: Decodable {
        let findGroup: Group?
    }
}
