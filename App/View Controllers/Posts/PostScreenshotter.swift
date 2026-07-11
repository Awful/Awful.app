//  PostScreenshotter.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulTheming
import UIKit
import WebKit

/// Renders posts into an offscreen WKWebView and captures screenshots.
@MainActor
final class PostScreenshotter {

    private static let maxSnapshotHeight: CGFloat = 16384

    /// Output pixel width for screenshots (1200px is ideal for social media).
    private static let outputPixelWidth: CGFloat = 1200

    /// Renders thumbnails for all posts, reusing a single WKWebView.
    /// Calls `onThumbnail` with each index and image as they complete.
    static func renderThumbnails(
        for posts: [Post],
        theme: Theme,
        width: CGFloat = 375,
        maxHeight: CGFloat = 300,
        onThumbnail: @MainActor (Int, UIImage) -> Void
    ) async {
        let loader = WebViewLoader(width: width)

        for (index, post) in posts.enumerated() {
            do {
                let html = try buildHTML(for: [post], theme: theme)
                let image = try await loadAndSnapshot(loader: loader, html: html, width: width, forThumbnail: true)

                let thumbWidth: CGFloat = 150
                let aspectRatio = image.size.height / max(image.size.width, 1)
                let thumbHeight = min(thumbWidth * aspectRatio, maxHeight)
                let thumbSize = CGSize(width: thumbWidth, height: thumbHeight)
                let thumbnail = UIGraphicsImageRenderer(size: thumbSize).image { _ in
                    image.draw(in: CGRect(origin: .zero, size: thumbSize))
                }
                onThumbnail(index, thumbnail)
            } catch {
                continue
            }
        }
    }

    /// Renders multiple posts stitched vertically into a single image.
    static func renderScreenshot(
        for posts: [Post],
        theme: Theme,
        width: CGFloat = 375
    ) async throws -> UIImage {
        let html = try buildHTML(for: posts, theme: theme)
        return try await loadAndSnapshot(html: html, width: width)
    }

    // MARK: - Private

    private static func buildHTML(for posts: [Post], theme: Theme) throws -> String {
        var context: [String: Any] = [:]
        context["stylesheet"] = theme[string: "postsViewCSS"] as Any
        context["externalStylesheet"] = PostsViewExternalStylesheetLoader.shared.stylesheet
        context["posts"] = posts.map { PostRenderModel($0).context }

        if let forum = posts.first?.thread?.forum, !forum.forumID.isEmpty {
            context["forumID"] = forum.forumID
        }
        if let thread = posts.first?.thread, !thread.threadID.isEmpty {
            context["threadID"] = thread.threadID
        }
        context["tweetTheme"] = theme[string: "postsTweetTheme"] ?? "light"

        return try StencilEnvironment.shared.renderTemplate(.postsView, context: context)
    }

    private static func loadAndSnapshot(
        html: String,
        width: CGFloat
    ) async throws -> UIImage {
        let loader = WebViewLoader(width: width)
        return try await loadAndSnapshot(loader: loader, html: html, width: width, forThumbnail: false)
    }

    private static func loadAndSnapshot(
        loader: WebViewLoader,
        html: String,
        width: CGFloat,
        forThumbnail: Bool
    ) async throws -> UIImage {
        loader.load(html: html)
        await loader.waitForLoad()

        if !forThumbnail {
            try await Task.sleep(nanoseconds: 300_000_000)
        }

        var contentHeight = try await loader.webView.evaluateJavaScript("document.body.scrollHeight") as? CGFloat ?? 1

        if forThumbnail {
            contentHeight = min(contentHeight, width)
        }

        if contentHeight <= maxSnapshotHeight {
            loader.webView.frame.size = CGSize(width: width, height: contentHeight)
            let config = WKSnapshotConfiguration()
            config.rect = CGRect(x: 0, y: 0, width: width, height: contentHeight)
            if !forThumbnail {
                config.snapshotWidth = NSNumber(value: Double(outputPixelWidth))
            }
            return try await loader.webView.takeSnapshot(configuration: config)
        } else {
            return try await tiledSnapshot(webView: loader.webView, width: width, totalHeight: contentHeight)
        }
    }

    private static func tiledSnapshot(
        webView: WKWebView,
        width: CGFloat,
        totalHeight: CGFloat
    ) async throws -> UIImage {
        let tileHeight = maxSnapshotHeight
        webView.frame.size = CGSize(width: width, height: totalHeight)

        var tiles: [(UIImage, CGFloat)] = []
        var yOffset: CGFloat = 0

        while yOffset < totalHeight {
            let remainingHeight = totalHeight - yOffset
            let currentTileHeight = min(tileHeight, remainingHeight)

            let config = WKSnapshotConfiguration()
            config.rect = CGRect(x: 0, y: yOffset, width: width, height: currentTileHeight)
            config.snapshotWidth = NSNumber(value: Double(outputPixelWidth))
            let tileImage = try await webView.takeSnapshot(configuration: config)
            tiles.append((tileImage, yOffset))
            yOffset += currentTileHeight
        }

        let scale = outputPixelWidth / width
        let pixelHeight = totalHeight * scale
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputPixelWidth, height: pixelHeight), format: format)
        return renderer.image { _ in
            for (tile, y) in tiles {
                tile.draw(in: CGRect(x: 0, y: y * scale, width: outputPixelWidth, height: tile.size.height))
            }
        }
    }

    /// Renders the watermark capsule as a standalone image for use as an annotation overlay.
    static func renderWatermark(isDark: Bool) -> UIImage {
        let logoName = isDark ? "platinum-member" : "platinum-member-white"
        let logo = UIImage(named: logoName)

        let urlText = "forums.somethingawful.com"

        let capsuleBackground: UIColor = isDark ? .white : .black
        let textColor: UIColor = isDark ? .black : .white

        let padding: CGFloat = 6
        let logoSize: CGFloat = 16
        let spacing: CGFloat = 4
        let fontSize: CGFloat = 11

        let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
        ]
        let textSize = (urlText as NSString).size(withAttributes: textAttributes)

        let capsuleWidth = padding + logoSize + spacing + textSize.width + padding
        let capsuleHeight = max(logoSize, textSize.height) + padding * 2

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: capsuleWidth, height: capsuleHeight))
        return renderer.image { _ in
            capsuleBackground.withAlphaComponent(0.6).setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: capsuleWidth, height: capsuleHeight), cornerRadius: capsuleHeight / 2).fill()

            let logoX = padding
            let logoY = (capsuleHeight - logoSize) / 2
            logo?.draw(in: CGRect(x: logoX, y: logoY, width: logoSize, height: logoSize))

            let textX = logoX + logoSize + spacing
            let textY = (capsuleHeight - textSize.height) / 2
            (urlText as NSString).draw(at: CGPoint(x: textX, y: textY), withAttributes: textAttributes)
        }
    }
}

// MARK: - Helper that owns a WKWebView and acts as its navigation delegate

@MainActor
private class WebViewLoader: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    private var continuation: CheckedContinuation<Void, Never>?

    init(width: CGFloat) {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(ImageURLProtocol(), forURLScheme: ImageURLProtocol.scheme)
        config.setURLSchemeHandler(ResourceURLProtocol(), forURLScheme: ResourceURLProtocol.scheme)

        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: width, height: 1), configuration: config)
        webView.isOpaque = true
        webView.backgroundColor = .white
        webView.scrollView.isScrollEnabled = false

        super.init()
        webView.navigationDelegate = self
    }

    func load(html: String) {
        webView.loadHTMLString(html, baseURL: ForumsClient.shared.baseURL)
    }

    func waitForLoad() async {
        await withCheckedContinuation { self.continuation = $0 }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated {
            continuation?.resume()
            continuation = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        MainActor.assumeIsolated {
            continuation?.resume()
            continuation = nil
        }
    }
}
