import Foundation

actor StashClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let serverURL: URL
    private let apiKey: String?

    init(serverURL: URL, apiKey: String?, session: URLSession = .shared) {
        self.serverURL = serverURL
        self.apiKey = apiKey
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func execute<Op: GraphQLOperation>(_ operation: Op) async throws -> Op.Response {
        let endpoint = serverURL.appending(path: "graphql")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "ApiKey")
        }

        let body = GraphQLRequestBody(
            operationName: operation.operationName,
            query: operation.query,
            variables: operation.variables
        )
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw StashError.decoding(error, bodyPreview: nil)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw StashError.transport(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw StashError.httpStatus(http.statusCode, bodyPreview: Self.preview(of: data))
        }

        let envelope: GraphQLResponse<Op.Response>
        do {
            envelope = try decoder.decode(GraphQLResponse<Op.Response>.self, from: data)
        } catch {
            #if DEBUG
            print("[StashClient] decode failed for \(endpoint.absoluteString):\n\(String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>")")
            #endif
            throw StashError.decoding(error, bodyPreview: Self.preview(of: data))
        }

        if let errors = envelope.errors, !errors.isEmpty {
            throw StashError.graphQL(errors)
        }
        guard let payload = envelope.data else {
            throw StashError.graphQL([])
        }
        return payload
    }
}

extension StashClient {
    @MainActor
    static func make(from config: ServerConfig) throws -> StashClient {
        guard let url = config.serverURL else { throw StashError.missingConfiguration }
        return StashClient(serverURL: url, apiKey: config.apiKey)
    }

    fileprivate static func preview(of data: Data, maxLength: Int = 300) -> String {
        let slice = data.prefix(maxLength)
        if let text = String(data: slice, encoding: .utf8) {
            let suffix = data.count > maxLength ? "…" : ""
            return text.trimmingCharacters(in: .whitespacesAndNewlines) + suffix
        }
        return "<\(data.count) bytes of non-UTF-8 data>"
    }
}
