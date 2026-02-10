import Combine
import Foundation
import Network

final class LocalWebServer: ObservableObject {
    enum Status: Equatable {
        case stopped
        case starting
        case running
        case failed(message: String)
    }

    static let host = "127.0.0.1"
    static let port: UInt16 = 54873

    @Published private(set) var status: Status = .stopped

    private var listener: NWListener?
    nonisolated private let queue = DispatchQueue(label: "isocity.localwebserver")
    nonisolated private let rootURL: URL
    nonisolated private static let requestHeaderTerminator = Data("\r\n\r\n".utf8)

    init(
        rootURL: URL? = Bundle.main.url(forResource: "web", withExtension: "bundle")
            ?? Bundle.main.resourceURL?.appendingPathComponent("web.bundle", isDirectory: true)
    ) {
        self.rootURL = rootURL ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    var baseURL: URL {
        URL(string: "http://\(Self.host):\(Self.port)")!
    }

    func startIfNeeded() {
        switch status {
        case .running, .starting:
            return
        case .stopped, .failed:
            break
        }

        do {
            try start()
        } catch {
            status = .failed(message: error.localizedDescription)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        status = .stopped
    }

    private func start() throws {
        status = .starting

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        let port = NWEndpoint.Port(rawValue: Self.port)!
        // We bind to a fixed port for a stable origin. Listening on all interfaces is fine since
        // we only ever load from 127.0.0.1 inside the app.
        let listener = try NWListener(using: params, on: port)

        listener.stateUpdateHandler = { [weak self] newState in
            guard let self else { return }
            Task { @MainActor in
                switch newState {
                case .ready:
                    self.status = .running
                case .failed(let error):
                    self.status = .failed(message: error.localizedDescription)
                case .cancelled:
                    self.status = .stopped
                default:
                    break
                }
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }

        self.listener = listener
        listener.start(queue: queue)
    }

    nonisolated private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, accumulated: Data())
    }

    nonisolated private func receiveRequest(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let error {
                self.sendSimpleResponse(connection: connection, status: "500 Internal Server Error", body: "Server error: \(error.localizedDescription)")
                return
            }

            var buffer = accumulated
            if let data {
                buffer.append(data)
            }

            if buffer.count > 256 * 1024 {
                self.sendSimpleResponse(connection: connection, status: "413 Payload Too Large", body: "Request too large.")
                return
            }

            if isComplete || buffer.range(of: Self.requestHeaderTerminator) != nil {
                guard let request = String(data: buffer, encoding: .utf8) else {
                    self.sendSimpleResponse(connection: connection, status: "400 Bad Request", body: "Invalid request encoding.")
                    return
                }
                self.handle(request: request, connection: connection)
                return
            }

            self.receiveRequest(on: connection, accumulated: buffer)
        }
    }

    nonisolated private func handle(request: String, connection: NWConnection) {
        guard let requestLine = request
            .split(whereSeparator: \.isNewline)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines), !requestLine.isEmpty else {
            sendSimpleResponse(connection: connection, status: "400 Bad Request", body: "Missing request line.")
            return
        }

        let parts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2 else {
            sendSimpleResponse(connection: connection, status: "400 Bad Request", body: "Malformed request line.")
            return
        }

        let method = String(parts[0])
        let target = String(parts[1])
        let normalizedTarget: String
        if let absoluteTarget = URL(string: target), absoluteTarget.scheme != nil {
            var absolutePath = absoluteTarget.path.isEmpty ? "/" : absoluteTarget.path
            if let query = absoluteTarget.query, !query.isEmpty {
                absolutePath += "?\(query)"
            }
            normalizedTarget = absolutePath
        } else {
            normalizedTarget = target
        }

        guard method == "GET" || method == "HEAD" else {
            sendSimpleResponse(connection: connection, status: "405 Method Not Allowed", body: "Only GET/HEAD supported.")
            return
        }

        let pathPart = normalizedTarget.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? "/"
        let decodedPath = pathPart.removingPercentEncoding ?? pathPart

        guard let relativePath = sanitizeRelativePath(decodedPath) else {
            sendSimpleResponse(connection: connection, status: "400 Bad Request", body: "Invalid path.")
            return
        }

        let fileURL = rootURL.appendingPathComponent(relativePath)
        let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let resolvedURL = isDirectory ? fileURL.appendingPathComponent("index.html") : fileURL

        guard resolvedURL.path.hasPrefix(rootURL.path) else {
            sendSimpleResponse(connection: connection, status: "403 Forbidden", body: "Forbidden.")
            return
        }

        guard let data = try? Data(contentsOf: resolvedURL) else {
            sendSimpleResponse(connection: connection, status: "404 Not Found", body: "Not found.")
            return
        }

        var responseData = responseHeader(
            status: "200 OK",
            contentType: mimeType(for: resolvedURL.pathExtension),
            contentLength: data.count
        )
        if method == "GET" {
            responseData.append(data)
        }

        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    nonisolated private func sendSimpleResponse(connection: NWConnection, status: String, body: String) {
        let data = Data(body.utf8)
        var response = responseHeader(
            status: status,
            contentType: "text/plain; charset=utf-8",
            contentLength: data.count
        )
        response.append(data)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    nonisolated private func responseHeader(status: String, contentType: String, contentLength: Int) -> Data {
        let lines = [
            "HTTP/1.1 \(status)",
            "Content-Type: \(contentType)",
            "Content-Length: \(contentLength)",
            "Connection: close",
            "",
            "",
        ]
        return Data(lines.joined(separator: "\r\n").utf8)
    }

    nonisolated private func sanitizeRelativePath(_ raw: String) -> String? {
        var path = raw
        if path.hasPrefix("/") {
            path.removeFirst()
        }

        if path.isEmpty {
            return "index.html"
        }

        // Next.js export frequently uses trailing slashes; map /foo/ -> foo/index.html.
        if path.hasSuffix("/") {
            path += "index.html"
        }

        let components = path.split(separator: "/", omittingEmptySubsequences: true)
        for component in components {
            if component == "." || component == ".." {
                return nil
            }
        }

        return components.joined(separator: "/")
    }

    nonisolated private func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html":
            return "text/html; charset=utf-8"
        case "js":
            return "application/javascript; charset=utf-8"
        case "css":
            return "text/css; charset=utf-8"
        case "json":
            return "application/json; charset=utf-8"
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "webp":
            return "image/webp"
        case "svg":
            return "image/svg+xml"
        case "ico":
            return "image/x-icon"
        case "woff2":
            return "font/woff2"
        case "ttf":
            return "font/ttf"
        case "map":
            return "application/json; charset=utf-8"
        default:
            return "application/octet-stream"
        }
    }
}
