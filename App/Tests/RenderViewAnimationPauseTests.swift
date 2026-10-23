//  RenderViewAnimationPauseTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import AwfulTheming
import UIKit
import WebKit
import XCTest

/// `RenderView.setAnimationsPaused` freezes GIFs by standing a canvas of the current frame in for each one. These tests render pages against a real `WKWebView` and read back what the document looks like: a bare page with a GIF avatar, GIFs in the post body (one bordered, one inside a scaled-down custom title) and a PNG, and the real posts stylesheet in the iPad layout.
@MainActor
final class RenderViewAnimationPauseTests: XCTestCase {

    private var window: UIWindow!
    private var renderView: RenderView!
    private var delegate: Delegate!
    private var imageServer: LocalImageServer!

    override func setUp() async throws {
        try await super.setUp()
        imageServer = try LocalImageServer()
        let frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
            window.frame = frame
        } else {
            window = UIWindow(frame: frame)
        }
        renderView = RenderView(frame: frame, includesLottiePlayer: false)
        delegate = Delegate()
        renderView.delegate = delegate
        let viewController = UIViewController()
        viewController.view.addSubview(renderView)
        window.rootViewController = viewController
        window.makeKeyAndVisible()
    }

    override func tearDown() async throws {
        window.isHidden = true
        window.rootViewController = nil
        imageServer.stop()
        try await super.tearDown()
    }

    private var pageHTML: String {
        """
        <!DOCTYPE html>
        <html><head><meta name="viewport" content="width=device-width"></head>
        <body>
        <post id="post1">
        <header><img class="avatar" id="avatar" src="\(imageServer.baseURL)/img/avatar.gif?h=50" alt=""></header>
        <section class="postbody">
        <p><img id="gif" src="\(imageServer.baseURL)/img/body.gif?h=120"></p>
        <p><img id="png" src="\(imageServer.baseURL)/img/still.png?h=80"></p>
        <p><img id="bordered" src="\(imageServer.baseURL)/img/border.gif?h=60" style="border: 3px solid red; padding: 2px"></p>
        <div class="customTitle" style="transform: scale(0.8); transform-origin: top left"><img id="scaled" src="\(imageServer.baseURL)/img/scaled.gif?h=90"></div>
        </section>
        </post>
        </body></html>
        """
    }

    /// Renders `html` and returns once the document has finished loading and every image in it has loaded.
    private func render(_ html: String) async throws {
        let rendered = expectation(description: "render finished")
        delegate.onDidFinishRendering = { rendered.fulfill() }
        renderView.render(html: html, baseURL: nil)
        await fulfillment(of: [rendered], timeout: 15)
        try await waitUntil("images loaded") {
            let loaded = try await self.eval("Array.from(document.images).every(function(img) { return img.complete && img.naturalWidth > 0; })")
            return (loaded as? Bool) == true
        }
    }

    private func waitForFrozenGIFs(_ count: Int) async throws {
        try await waitUntil("\(count) GIFs frozen") {
            (try await self.eval("document.querySelectorAll('canvas.awful-frozen-gif').length") as? NSNumber)?.intValue == count
        }
    }

    func testPausingFreezesGIFsAndLeavesStillImagesAlone() async throws {
        try await render(pageHTML)
        let ids = ["avatar", "gif", "png", "bordered", "scaled"]
        let before = try await rects(of: ids)

        renderView.setAnimationsPaused(true)
        try await waitForFrozenGIFs(4)

        let avatarDisplay = try await display(of: "avatar")
        let gifDisplay = try await display(of: "gif")
        let pngDisplay = try await display(of: "png")
        let standInHasAvatarClass = try await eval("document.getElementById('avatar').nextElementSibling.classList.contains('avatar')") as? Bool
        XCTAssertEqual(avatarDisplay, "none")
        XCTAssertEqual(gifDisplay, "none")
        XCTAssertNotEqual(pngDisplay, "none", "a PNG isn't a GIF and shouldn't be touched")
        XCTAssertEqual(standInHasAvatarClass, true, "the stand-in keeps the image's classes so avatar styling applies")

        // The canvases take exactly the space the images did, so nothing shifts. That includes the bordered image, whose border the canvas lacks, and the one in a scaled-down custom title, which must not be scaled twice.
        let after = try await rects(of: ids, frozenStandIns: true)
        for id in ids {
            XCTAssertEqual(after[id], before[id], "\(id) moved or resized when frozen")
        }
    }

    func testResumingRestoresTheImages() async throws {
        try await render(pageHTML)
        renderView.setAnimationsPaused(true)
        try await waitForFrozenGIFs(4)

        renderView.setAnimationsPaused(false)
        try await waitForFrozenGIFs(0)
        let avatarDisplay = try await display(of: "avatar")
        let gifDisplay = try await display(of: "gif")
        let frozenCount = try await eval("document.querySelectorAll('[data-awful-frozen]').length") as? NSNumber
        XCTAssertNotEqual(avatarDisplay, "none")
        XCTAssertNotEqual(gifDisplay, "none")
        XCTAssertEqual(frozenCount, 0)
    }

    func testPageRenderedWhilePausedStartsFrozen() async throws {
        renderView.setAnimationsPaused(true)
        try await render(pageHTML)
        try await waitForFrozenGIFs(4)
        let paused = try await eval("Awful.animationsPaused") as? Bool
        XCTAssertEqual(paused, true)
    }

    /// The real posts markup and stylesheet, in the iPad layout: a header avatar, a post body GIF, and a custom title whose first image is the avatar (what the iPad and Mac layout shows when custom titles are on).
    private var styledPageHTML: String {
        let css = Theme.defaultTheme(mode: .light)[string: "postsViewCSS"] ?? ""
        return """
        <!DOCTYPE html>
        <meta charset="utf-8">
        <meta name="viewport" content="width=320, initial-scale=0.99, viewport-fit=cover">
        <style id="awful-inline-style">\(css)</style>
        <body class="ipad">
        <div id="posts">
        <post id="p1">
            <header><img class="avatar" id="avatar" src="\(imageServer.baseURL)/img/avatar.gif?h=100" alt=""><section class="nameanddate"><span class="username">Someone</span></section></header>
            <section class="postbody"><p>Hello <img id="gif" src="\(imageServer.baseURL)/img/body.gif?h=120"></p></section>
            <footer><span class="postdate">now</span></footer>
        </post>
        <post id="p2" class="responsive">
            <header class="responsive">
                <section class="nameanddate"><span class="username">Else</span></section>
                <div class="customTitle responsive"><img id="titleAvatar" src="\(imageServer.baseURL)/img/title.gif?h=125" border="0"><br>A custom title</div>
            </header>
            <section class="postbody responsive"><p>There</p></section>
            <footer><span class="postdate">now</span></footer>
        </post>
        </div>
        </body>
        """
    }

    func testFreezingKeepsLayoutWithThePostsStylesheet() async throws {
        // Wide enough for the iPad layout's responsive header (400 points and up).
        window.frame = CGRect(x: 0, y: 0, width: 1024, height: 768)
        renderView.frame = window.bounds
        try await render(styledPageHTML)
        let ids = ["avatar", "gif", "titleAvatar"]
        let before = try await rects(of: ids)

        renderView.setAnimationsPaused(true)
        try await waitForFrozenGIFs(3)
        let after = try await rects(of: ids, frozenStandIns: true)
        for id in ids {
            XCTAssertEqual(after[id], before[id], "\(id) moved or resized when frozen")
        }
    }

    // MARK: Helpers

    private final class Delegate: RenderViewDelegate {
        var onDidFinishRendering: (() -> Void)?
        func didFinishRenderingHTML(in view: RenderView) { onDidFinishRendering?() }
        func didReceive(message: RenderViewMessage, in view: RenderView) {}
        func didTapLink(to url: URL, in view: RenderView) {}
        func renderProcessDidTerminate(in view: RenderView) {}
    }

    private func eval(_ javaScript: String) async throws -> Any? {
        try await renderView.evalForTesting(javaScript)
    }

    private func display(of id: String) async throws -> String? {
        try await eval("getComputedStyle(document.getElementById('\(id)')).display") as? String
    }

    /// Bounding rects of the elements with `ids`, rounded to whole pixels. With `frozenStandIns`, a hidden frozen image is measured through the canvas standing in for it.
    private func rects(of ids: [String], frozenStandIns: Bool = false) async throws -> [String: [Int]] {
        let idsJSON = String(data: try JSONEncoder().encode(ids), encoding: .utf8)!
        let result = try await eval("""
            (function() {
                var out = {};
                \(idsJSON).forEach(function(id) {
                    var el = document.getElementById(id);
                    if (\(frozenStandIns) && el.dataset.awfulFrozen) { el = el.nextElementSibling; }
                    var r = el.getBoundingClientRect();
                    out[id] = [Math.round(r.left), Math.round(r.top), Math.round(r.width), Math.round(r.height)];
                });
                return out;
            })()
            """)
        return (result as? [String: [NSNumber]])?.mapValues { $0.map(\.intValue) } ?? [:]
    }

    private func waitUntil(_ what: String, timeout: TimeInterval = 10, _ condition: @escaping () async throws -> Bool) async throws {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            if try await condition() { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("timed out waiting for \(what)")
    }
}
