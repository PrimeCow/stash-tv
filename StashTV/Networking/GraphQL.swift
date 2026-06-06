import Foundation

protocol GraphQLOperation {
    associatedtype Response: Decodable
    var operationName: String { get }
    var query: String { get }
    var variables: [String: AnyEncodable]? { get }
}

extension GraphQLOperation {
    var variables: [String: AnyEncodable]? { nil }
}

struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void

    init<T: Encodable>(_ wrapped: T) {
        self.encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}

struct GraphQLRequestBody<Variables: Encodable>: Encodable {
    let operationName: String
    let query: String
    let variables: Variables?
}

struct GraphQLResponse<Data: Decodable>: Decodable {
    let data: Data?
    let errors: [GraphQLError]?
}

struct GraphQLError: Decodable, Error, CustomStringConvertible {
    let message: String
    let path: [String]?
    var description: String { message }
}

enum StashError: Error, LocalizedError {
    case missingConfiguration
    case httpStatus(Int)
    case graphQL([GraphQLError])
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration: "Server URL is not configured."
        case .httpStatus(let code): "Server returned HTTP \(code)."
        case .graphQL(let errors): errors.map(\.message).joined(separator: "; ")
        case .decoding(let error): "Decoding failed: \(error.localizedDescription)"
        case .transport(let error): error.localizedDescription
        }
    }
}
