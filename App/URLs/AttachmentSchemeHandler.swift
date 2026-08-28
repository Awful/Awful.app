//  AttachmentSchemeHandler.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import WebKit

/**
 Serves Something Awful attachments (`attachment.php?attachmentid=N`) to web views at `awful-attachment:///N`, fetching them lazily via `ForumsClient`'s authenticated session.

 `attachment.php` requires the logged-in session cookie, which lives in `HTTPCookieStorage.shared` and never reaches the web view's cookie store, so the web view can't load attachments directly. Register this handler on a `WKWebViewConfiguration` and rewrite attachment `img` sources to `serveURL(attachmentID:)`; WebKit then fetches attachments like any other image: during page parse, concurrently, with no JavaScript involved.

 Fetched attachments are kept in a shared in-memory cache and concurrent requests for the same attachment are coalesced, so a re-render (e.g. after a theme change) or a duplicate attachment within one page costs a single network round-trip.
 */
final class AttachmentSchemeHandler: NSObject, WKURLSchemeHandler {

    static let scheme = "awful-attachment"

    /// The URL to use as an `img` src for the given attachment.
    static func serveURL(attachmentID: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.path = "/\(attachmentID)"
        return components.url
    }

    final class CachedAttachment {
        let data: Data
        let mimeType: String
        init(data: Data, mimeType: String) {
            self.data = data
            self.mimeType = mimeType
        }
    }

    private static let cache: NSCache<NSString, CachedAttachment> = {
        let cache = NSCache<NSString, CachedAttachment>()
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    @MainActor private static var inflight: [String: Task<CachedAttachment, Swift.Error>] = [:]

    /// Live scheme tasks. WebKit calls `start`/`stop` on the main thread; a task absent here has been stopped (or finished) and must not be called back, as that raises an Objective-C exception.
    private var liveTasks: Set<ObjectIdentifier> = []

    func webView(_ webView: WKWebView, start schemeTask: WKURLSchemeTask) {
        let key = ObjectIdentifier(schemeTask)
        liveTasks.insert(key)
        Task { @MainActor in
            do {
                guard let url = schemeTask.request.url else { throw URLError(.badURL) }
                let attachmentID = String(url.path.dropFirst())
                // Digits only, so the authenticated session can only ever be pointed at attachment.php?attachmentid=N.
                guard !attachmentID.isEmpty, attachmentID.allSatisfy({ $0.isASCII && $0.isNumber }) else {
                    throw URLError(.badURL)
                }

                let attachment = try await Self.attachment(id: attachmentID)

                guard self.liveTasks.remove(key) != nil else { return }
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [
                    "Content-Type": attachment.mimeType,
                    "Content-Length": "\(attachment.data.count)"])!
                schemeTask.didReceive(response)
                schemeTask.didReceive(attachment.data)
                schemeTask.didFinish()
            } catch {
                guard self.liveTasks.remove(key) != nil else { return }
                schemeTask.didFailWithError(error)
            }
        }
    }

    func webView(_ webView: WKWebView, stop schemeTask: WKURLSchemeTask) {
        liveTasks.remove(ObjectIdentifier(schemeTask))
    }

    /// Returns the attachment from cache, joining any in-flight fetch, otherwise fetching it via the authenticated session.
    @MainActor static func attachment(id: String) async throws -> CachedAttachment {
        if let cached = cache.object(forKey: id as NSString) { return cached }
        if let inflight = inflight[id] { return try await inflight.value }

        let fetch = Task<CachedAttachment, Swift.Error> {
            let (data, serverMIMEType) = try await ForumsClient.shared.fetchAttachment(id: id)
            // Sniff the actual bytes first: the server may claim application/octet-stream, and an expired session gets an HTML login page instead of an image.
            guard let mimeType = sniffImageMIMEType(data) ?? serverMIMEType.flatMap({ $0.hasPrefix("image/") ? $0 : nil }) else {
                throw URLError(.cannotDecodeContentData)
            }
            let attachment = CachedAttachment(data: data, mimeType: mimeType)
            cache.setObject(attachment, forKey: id as NSString, cost: data.count)
            return attachment
        }
        inflight[id] = fetch
        defer { inflight[id] = nil }
        return try await fetch.value
    }
}

/// Identifies common image formats by their leading bytes.
private func sniffImageMIMEType(_ data: Data) -> String? {
    func hasPrefix(_ bytes: [UInt8], at offset: Int = 0) -> Bool {
        guard data.count >= offset + bytes.count else { return false }
        return data.dropFirst(offset).prefix(bytes.count).elementsEqual(bytes)
    }
    if hasPrefix([0x47, 0x49, 0x46, 0x38]) { return "image/gif" }
    if hasPrefix([0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
    if hasPrefix([0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
    if hasPrefix([0x52, 0x49, 0x46, 0x46]), hasPrefix([0x57, 0x45, 0x42, 0x50], at: 8) { return "image/webp" }
    if hasPrefix([0x42, 0x4D]) { return "image/bmp" }
    return nil
}
