import Foundation

struct VersionQuery: GraphQLOperation {
    typealias Response = Data

    let operationName = "Version"
    let query = """
    query Version {
      version { version build_time hash }
    }
    """

    struct Data: Decodable {
        let version: VersionInfo
    }

    struct VersionInfo: Decodable {
        let version: String
        let build_time: String?
        let hash: String?
    }
}
