import Foundation
import Network

/// A throwaway HTTP server used to enter the Stash URL + API key from a phone
/// instead of typing them on the TV with the remote. It listens on the LAN,
/// serves a small form, and reports the submitted values back via `handler`.
///
/// All mutable state lives on `queue`; the type is `@unchecked Sendable` on that
/// promise. State/results reach the UI through the `@Sendable` handler, which
/// hops to the main actor in `PairingModel`.
final class PairingServer: @unchecked Sendable {
    enum Event: Sendable {
        case started(address: String)
        case failed(String)
        case received(serverURL: String, apiKey: String?)
    }

    private let queue = DispatchQueue(label: "stashtv.pairing")
    private let handler: @Sendable (Event) -> Void
    private var listener: NWListener?

    init(handler: @escaping @Sendable (Event) -> Void) {
        self.handler = handler
    }

    func start() {
        queue.async { [weak self] in self?.startOnQueue() }
    }

    func stop() {
        queue.async { [weak self] in
            self?.listener?.cancel()
            self?.listener = nil
        }
    }

    private func startOnQueue() {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let listener = try NWListener(using: params, on: .any)
            self.listener = listener
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    let port = listener.port?.rawValue ?? 0
                    let ip = Self.localIPAddress() ?? "this-tv.local"
                    self.handler(.started(address: "http://\(ip):\(port)"))
                case .failed(let error):
                    self.handler(.failed(error.localizedDescription))
                default:
                    break
                }
            }
            listener.start(queue: queue)
        } catch {
            handler(.failed(error.localizedDescription))
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection, buffer: Data())
    }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { connection.cancel(); return }
            var buffer = buffer
            if let data, !data.isEmpty { buffer.append(data) }

            if let request = HTTPRequest(buffer) {
                self.respond(connection, to: request)
            } else if isComplete || error != nil {
                connection.cancel()
            } else {
                self.receive(connection, buffer: buffer)
            }
        }
    }

    private func respond(_ connection: NWConnection, to request: HTTPRequest) {
        let response: String
        if request.method == "POST", request.path.hasPrefix("/pair") {
            let fields = Self.parseForm(request.body)
            let url = (fields["serverURL"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let rawKey = (fields["apiKey"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if url.isEmpty {
                response = Self.httpResponse(html: Self.formPage(error: "Server URL is required."), status: "400 Bad Request")
            } else {
                handler(.received(serverURL: url, apiKey: rawKey.isEmpty ? nil : rawKey))
                response = Self.httpResponse(html: Self.successPage())
            }
        } else {
            response = Self.httpResponse(html: Self.formPage(error: nil))
        }
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - HTTP helpers

    private static func parseForm(_ body: String) -> [String: String] {
        var result: [String: String] = [:]
        for pair in body.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard kv.count == 2 else { continue }
            result[decode(String(kv[0]))] = decode(String(kv[1]))
        }
        return result
    }

    private static func decode(_ value: String) -> String {
        let spaced = value.replacingOccurrences(of: "+", with: " ")
        return spaced.removingPercentEncoding ?? spaced
    }

    private static func httpResponse(html: String, status: String = "200 OK") -> String {
        let headers = "HTTP/1.1 \(status)\r\n"
            + "Content-Type: text/html; charset=utf-8\r\n"
            + "Content-Length: \(html.utf8.count)\r\n"
            + "Connection: close\r\n\r\n"
        return headers + html
    }

    private static func formPage(error: String?) -> String {
        let banner = error.map { "<p class=err>\($0)</p>" } ?? ""
        return """
        <!doctype html><html><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>stash-tv pairing</title>
        <style>
          :root { color-scheme: dark; }
          body { font-family: -apple-system, system-ui, sans-serif; background:#0a0a0b; color:#fff; margin:0; padding:28px; }
          h1 { font-size:24px; margin:0 0 4px; }
          p { color:#9aa0a6; line-height:1.4; }
          .err { color:#ff5a5f; }
          label { display:block; margin:18px 0 6px; font-weight:600; }
          input { width:100%; box-sizing:border-box; padding:14px; font-size:17px; border:1px solid #2a2c30; border-radius:10px; background:#161719; color:#fff; }
          button { margin-top:24px; width:100%; padding:16px; font-size:18px; font-weight:700; border:none; border-radius:10px; background:#e0245e; color:#fff; }
        </style></head><body>
        <h1>stash-tv</h1>
        <p>Send your Stash server URL and API key to the TV.</p>
        \(banner)
        <form method="POST" action="/pair">
          <label>Server URL</label>
          <input name="serverURL" type="url" inputmode="url" autocapitalize="off" autocorrect="off" spellcheck="false" placeholder="https://stash.example.com" required>
          <label>API Key <span style="color:#9aa0a6;font-weight:400">(optional)</span></label>
          <input name="apiKey" type="text" autocapitalize="off" autocorrect="off" spellcheck="false" placeholder="Leave blank if no auth">
          <button type="submit">Send to TV</button>
        </form>
        </body></html>
        """
    }

    private static func successPage() -> String {
        """
        <!doctype html><html><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Sent</title>
        <style>
          body { font-family:-apple-system,system-ui,sans-serif; background:#0a0a0b; color:#fff; margin:0; padding:48px; text-align:center; }
          h1 { font-size:26px; }
          p { color:#9aa0a6; font-size:18px; }
        </style></head><body>
        <h1>✓ Sent to your TV</h1>
        <p>You can put your phone down and finish on the TV.</p>
        </body></html>
        """
    }

    // MARK: - LAN address

    private static func localIPAddress() -> String? {
        var candidates: [String: String] = [:]
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            guard (flags & IFF_UP) == IFF_UP, (flags & IFF_LOOPBACK) == 0 else { continue }
            guard let addr = ptr.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            guard result == 0 else { continue }
            candidates[String(cString: ptr.pointee.ifa_name)] = String(cString: host)
        }
        // en0 is Wi-Fi/Ethernet on Apple TV; fall back to whatever is up.
        return candidates["en0"] ?? candidates["en1"] ?? candidates.values.first
    }
}

/// Minimal HTTP request parse. `init?` returns nil until the full request
/// (headers, plus a body of `Content-Length` bytes for POST) has arrived.
private struct HTTPRequest {
    let method: String
    let path: String
    let body: String

    init?(_ data: Data) {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = data.subdata(in: data.startIndex..<headerEnd.lowerBound)
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }

        let lines = headerText.components(separatedBy: "\r\n")
        let parts = (lines.first ?? "").split(separator: " ")
        guard parts.count >= 2 else { return nil }
        method = String(parts[0])
        path = String(parts[1])

        var contentLength = 0
        for line in lines.dropFirst() where line.lowercased().hasPrefix("content-length:") {
            let value = line.drop(while: { $0 != ":" }).dropFirst()
            contentLength = Int(value.trimmingCharacters(in: .whitespaces)) ?? 0
        }

        let bodyStart = headerEnd.upperBound
        let available = data.endIndex - bodyStart
        guard available >= contentLength else { return nil }
        let bodyData = data.subdata(in: bodyStart..<(bodyStart + contentLength))
        body = String(data: bodyData, encoding: .utf8) ?? ""
    }
}

/// Main-actor wrapper that drives a `PairingServer` and exposes its state to SwiftUI.
@MainActor
@Observable
final class PairingModel {
    enum Status: Equatable {
        case starting
        case running(address: String)
        case received
        case failed(String)
    }

    private(set) var status: Status = .starting
    var onReceive: ((String, String?) -> Void)?

    private var server: PairingServer?

    func start() {
        guard server == nil else { return }
        let server = PairingServer { [weak self] event in
            Task { @MainActor in self?.apply(event) }
        }
        self.server = server
        server.start()
    }

    func stop() {
        server?.stop()
        server = nil
    }

    private func apply(_ event: PairingServer.Event) {
        switch event {
        case .started(let address):
            status = .running(address: address)
        case .failed(let message):
            status = .failed(message)
        case .received(let serverURL, let apiKey):
            status = .received
            onReceive?(serverURL, apiKey)
        }
    }
}
