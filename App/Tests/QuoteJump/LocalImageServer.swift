//  LocalImageServer.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import Network
import UIKit

/// A tiny HTTP server on the loopback interface that answers `GET /img/<name>.png?delay=<ms>&h=<px>` with a solid PNG `h` pixels tall, after `delay` milliseconds. The quotejump fixtures point their images here (see `Scripts/make-quotejump-fixtures.py`), so a scenario controls exactly when media above a jump target finishes loading and by how much it grows. `WKWebView` can't be served by a `URLProtocol`, hence a real socket.
final class LocalImageServer {

    /// The server's origin, e.g. `http://127.0.0.1:54321`, for substituting into fixture HTML.
    private(set) var baseURL = ""

    /// How many image responses have been sent in full, for asserting that a scenario's images did load.
    var servedCount: Int { lock.withLock { _servedCount } }

    private let listener: NWListener
    private let queue = DispatchQueue(label: "com.awfulapp.Awful.tests.LocalImageServer")
    private let lock = NSLock()
    private var _servedCount = 0
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var pngCache: [Int: Data] = [:]

    /// Starts listening on an ephemeral port and returns once the port is known.
    init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .loopback
        parameters.allowLocalEndpointReuse = true
        listener = try NWListener(using: parameters, on: .any)

        let ready = DispatchSemaphore(value: 0)
        var startupError: Error?
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                ready.signal()
            case .failed(let error):
                startupError = error
                ready.signal()
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)
        guard ready.wait(timeout: .now() + 5) == .success else {
            throw StartupError.timedOut
        }
        if let startupError { throw startupError }
        guard let port = listener.port?.rawValue else { throw StartupError.noPort }
        baseURL = "http://127.0.0.1:\(port)"
    }

    enum StartupError: Error {
        case timedOut
        case noPort
    }

    func stop() {
        listener.cancel()
        queue.sync {
            connections.values.forEach { $0.cancel() }
            connections.removeAll()
        }
    }

    private func accept(_ connection: NWConnection) {
        connections[ObjectIdentifier(connection)] = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .failed, .cancelled:
                self.connections.removeValue(forKey: ObjectIdentifier(connection))
            default:
                break
            }
        }
        connection.start(queue: queue)
        receiveRequest(on: connection, buffered: Data())
    }

    private func receiveRequest(on connection: NWConnection, buffered: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffered = buffered
            if let data { buffered.append(data) }
            if let headerEnd = buffered.range(of: Data("\r\n\r\n".utf8)) {
                let head = String(decoding: buffered[..<headerEnd.lowerBound], as: UTF8.self)
                self.respond(toRequestHead: head, on: connection)
            } else if isComplete || error != nil {
                connection.cancel()
            } else {
                self.receiveRequest(on: connection, buffered: buffered)
            }
        }
    }

    private func respond(toRequestHead head: String, on connection: NWConnection) {
        let requestLine = head.split(separator: "\r\n").first.map(String.init) ?? ""
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2, let components = URLComponents(string: String(parts[1])) else {
            send(status: "400 Bad Request", contentType: "text/plain", body: Data(), on: connection)
            return
        }
        func query(_ name: String) -> String? { components.queryItems?.first(where: { $0.name == name })?.value }

        guard components.path.hasPrefix("/img/") else {
            send(status: "404 Not Found", contentType: "text/plain", body: Data(), on: connection)
            return
        }
        let height = max(1, min(4000, query("h").flatMap { Int($0) } ?? 100))
        let delay = max(0, min(30_000, query("delay").flatMap { Int($0) } ?? 0))

        let png = self.png(height: height)
        queue.asyncAfter(deadline: .now() + .milliseconds(delay)) { [weak self] in
            guard let self else { return }
            self.send(status: "200 OK", contentType: "image/png", body: png, on: connection) {
                self.lock.withLock { self._servedCount += 1 }
            }
        }
    }

    private func send(status: String, contentType: String, body: Data, on connection: NWConnection, completion: (() -> Void)? = nil) {
        var response = Data("HTTP/1.1 \(status)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n".utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { _ in
            completion?()
            connection.cancel()
        })
    }

    /// A solid 200 pixel wide PNG, cached per height. 200 is narrower than any phone viewport, so the posts stylesheet's `max-width: 100%` never scales it and the rendered height is exactly `height` CSS pixels.
    private func png(height: Int) -> Data {
        if let cached = pngCache[height] { return cached }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: height), format: format)
        let image = renderer.image { context in
            UIColor(hue: CGFloat(height % 360) / 360, saturation: 0.6, brightness: 0.8, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: height))
        }
        let data = image.pngData() ?? Data()
        pngCache[height] = data
        return data
    }
}
