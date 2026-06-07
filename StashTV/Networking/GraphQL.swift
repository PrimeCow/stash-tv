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
    case httpStatus(Int, bodyPreview: String?)
    case graphQL([GraphQLError])
    case decoding(Error, bodyPreview: String?)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration: "Server URL is not configured."
        case .httpStatus(let code, let preview):
            "Server returned HTTP \(code).\(Self.formatPreview(preview))"
        case .graphQL(let errors): errors.map(\.message).joined(separator: "; ")
        case .decoding(let error, let preview):
            "Decoding failed: \(Self.describe(decodingError: error))\(Self.formatPreview(preview))"
        case .transport(let error): error.localizedDescription
        }
    }

    private static func formatPreview(_ preview: String?) -> String {
        guard let preview, !preview.isEmpty else { return "" }
        return "\n\nServer response (first \(preview.count) chars):\n\(preview)"
    }

    private static func describe(decodingError error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }
        switch decodingError {
        case .typeMismatch(let type, let ctx):
            return "type mismatch (\(type)) at \(path(ctx.codingPath)): \(ctx.debugDescription)"
        case .valueNotFound(let type, let ctx):
            return "missing value (\(type)) at \(path(ctx.codingPath)): \(ctx.debugDescription)"
        case .keyNotFound(let key, let ctx):
            return "missing key '\(key.stringValue)' at \(path(ctx.codingPath))"
        case .dataCorrupted(let ctx):
            return "data corrupted at \(path(ctx.codingPath)): \(ctx.debugDescription)"
        @unknown default:
            return decodingError.localizedDescription
        }
    }

    private static func path(_ codingPath: [CodingKey]) -> String {
        codingPath.isEmpty ? "<root>" : codingPath.map(\.stringValue).joined(separator: ".")
    }
}
