import Foundation

struct FindSavedFiltersQuery: GraphQLOperation {
    typealias Response = Data

    let mode: String

    init(mode: String = "SCENES") { self.mode = mode }

    let operationName = "FindSavedFilters"

    let query = """
    query FindSavedFilters($mode: FilterMode) {
      findSavedFilters(mode: $mode) {
        id
        mode
        name
        find_filter { q sort direction per_page }
        object_filter
      }
    }
    """

    var variables: [String: AnyEncodable]? {
        ["mode": AnyEncodable(mode)]
    }

    struct Data: Decodable {
        let findSavedFilters: [SavedFilter]
    }
}
