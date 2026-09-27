//  PlatinumIconsTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class PlatinumIconsTests: XCTestCase {

    private func siteStylesheet() throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "platicons", withExtension: "css", subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func imageURLs(_ icons: [PlatinumIcon]) -> [String: String] {
        Dictionary(icons.map { ($0.className, $0.imageURL.absoluteString) }, uniquingKeysWith: { $1 })
    }

    func testSiteStylesheet() throws {
        let icons = PlatinumIcons.parse(siteStylesheet: try siteStylesheet())
        let urls = imageURLs(icons)

        XCTAssertGreaterThan(icons.count, 150)
        XCTAssertEqual(Set(icons.map(\.className)).count, icons.count, "no duplicates")

        XCTAssertEqual(urls["feather"], "https://fi.somethingawful.com/images/svgs/feather.svg")
        XCTAssertEqual(urls["pumpkin"], "https://fi.somethingawful.com/images/svgs/pumpkin.svg")
        XCTAssertEqual(urls["astral"], "https://fi.somethingawful.com/images/usericons/astral_2207.jpg")
        XCTAssertEqual(urls["razz-blue"], "https://fi.somethingawful.com/images/svgs/razz-blue.png")
        XCTAssertEqual(urls["pentagram"], "https://fi.somethingawful.com/images/svgs/antimod2.svg")

        // Protocol-relative URLs, including on other Forums hosts.
        XCTAssertEqual(urls["fire"], "https://fi.somethingawful.com/images/svgs/fireicon.gif")
        XCTAssertEqual(urls["labfeather"], "https://downloads.somethingawful.com/misc/labird.png")

        // After the comment.
        XCTAssertEqual(urls["mycatisnorris"], "https://fi.somethingawful.com/images/svgs/dog.svg")

        // Styled by the posts view itself.
        XCTAssertNil(urls["coder"])
        XCTAssertNil(urls["idiotking"])
        XCTAssertNil(urls["diamond"])
    }

    func testRejectsUnsafeRules() {
        let css = """
            #thread dl.userinfo dt.good { background-image: url(//fi.somethingawful.com/good.svg); }
            #thread dl.userinfo dt.elsewhere { background-image: url(https://example.com/bad.svg); }
            #thread dl.userinfo dt.lookalike { background-image: url(https://notsomethingawful.com/bad.svg); }
            #thread dl.userinfo dt.script { background-image: url(javascript:alert(1)); }
            #thread dl.userinfo dt.quote { background-image: url('https://fi.somethingawful.com/a".svg'); }
            #thread dl.userinfo dt.9lives { background-image: url(https://fi.somethingawful.com/bad.svg); }
            #thread dl.userinfo dt.two.classes { background-image: url(https://fi.somethingawful.com/bad.svg); }
            #thread dl.userinfo dt.role-mod { background-image: url(https://fi.somethingawful.com/bad.svg); }
            #thread dl.userinfo dt.seen { background-image: url(https://fi.somethingawful.com/bad.svg); }
            td.userid-1 dd.special_title::after { background-image: url(https://fi.somethingawful.com/bad.svg); }
            #thread dl.userinfo dt.nourl { background-size: 20px; }
            #thread dl.userinfo dt.plain { background-image: url(http://fi.somethingawful.com/plain.svg); }
            """
        let urls = imageURLs(PlatinumIcons.parse(siteStylesheet: css))
        XCTAssertEqual(urls, [
            "good": "https://fi.somethingawful.com/good.svg",
            "plain": "https://fi.somethingawful.com/plain.svg",
        ])
    }

    func testLaterRuleWins() {
        let css = """
            dt.dup { background-image: url(https://fi.somethingawful.com/first.svg); }
            dt.dup { background-image: url(https://fi.somethingawful.com/second.svg); }
            """
        let icons = PlatinumIcons.parse(siteStylesheet: css)
        XCTAssertEqual(icons, [PlatinumIcon(className: "dup", imageURL: URL(string: "https://fi.somethingawful.com/second.svg")!)])
    }

    func testPostsViewStylesheet() {
        let black = PlatinumIcon(className: "feather", imageURL: URL(string: "https://fi.somethingawful.com/feather.svg")!)
        let colour = PlatinumIcon(className: "pumpkin", imageURL: URL(string: "https://fi.somethingawful.com/pumpkin.svg")!)
        let css = PlatinumIcons.postsViewStylesheet(for: [black, colour], isBlack: { $0 == black.imageURL })

        XCTAssertTrue(css.contains("post.feather .username:after,\npost.pumpkin .username:after {"))
        XCTAssertTrue(css.contains(#"post.feather .username:after { background-image: url("https://fi.somethingawful.com/feather.svg"); -webkit-filter: var(--awful-black-icon-filter, none);"#))
        XCTAssertTrue(css.contains(#"post.pumpkin .username:after { background-image: url("https://fi.somethingawful.com/pumpkin.svg"); }"#))

        XCTAssertEqual(PlatinumIcons.postsViewStylesheet(for: [], isBlack: { _ in true }), "")
    }

    // MARK: Black icons

    private func svg(_ body: String) -> Data {
        Data(##"<?xml version="1.0"?><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">\##(body)</svg>"##.utf8)
    }

    func testBlackSVGs() {
        XCTAssertTrue(PlatinumIcons.isBlack(imageData: svg(#"<path d="M0 0h32v32z"/>"#)), "no fill is black")
        XCTAssertTrue(PlatinumIcons.isBlack(imageData: svg(##"<path fill="#000" d="M0 0h32v32z"/><path fill="#222222" stroke="black" d="M0 0h8v8z"/>"##)), "dark grey shading")
        XCTAssertTrue(PlatinumIcons.isBlack(imageData: svg(##"<style>.a{fill:#000000;}</style><path class="a" style="fill:rgb(0%,0%,0%);stroke:none" d="M0 0h32v32z"/>"##)))
        XCTAssertTrue(PlatinumIcons.isBlack(imageData: svg(##"<path fill="none" stroke="currentColor" fill-rule="evenodd" stroke-width="2" d="M0 0h32v32z"/>"##)))
        XCTAssertTrue(PlatinumIcons.isBlack(imageData: svg(##"<sodipodi:namedview pagecolor="#ffffff" bordercolor="#666666"/><path d="M0 0h32v32z"/>"##)), "editor metadata isn't drawn")
    }

    func testNotBlackSVGs() {
        XCTAssertFalse(PlatinumIcons.isBlack(imageData: svg(##"<path fill="#76b5dd" d="M0 0h32v32z"/>"##)), "blue")
        XCTAssertFalse(PlatinumIcons.isBlack(imageData: svg(##"<path d="M0 0h32v32z"/><path fill="#fff" d="M0 0h8v8z"/>"##)), "white detail")
        XCTAssertFalse(PlatinumIcons.isBlack(imageData: svg(##"<path fill="red" d="M0 0h32v32z"/>"##)), "named colour")
        XCTAssertFalse(PlatinumIcons.isBlack(imageData: svg(##"<image href="data:image/png;base64,AAAA"/>"##)), "embedded image")
        XCTAssertFalse(PlatinumIcons.isBlack(imageData: svg(##"<linearGradient id="g"><stop stop-color="#000"/></linearGradient><path fill="url(#g)" d="M0 0h32v32z"/>"##)), "gradient")
        XCTAssertFalse(PlatinumIcons.isBlack(imageData: svg(##"<path fill="#nothex" d="M0 0h32v32z"/>"##)), "unparseable")
    }

    func testCSSColors() {
        for black in ["#000", "#000000", "#0008", "#00000080", "black", "BLACK", "#333", "#404040", "rgb(0,0,0)", "rgb(0 0 0 / 50%)", "rgba(10, 20, 30, 0.5)", "rgb(25%, 0%, 0%)", "#000 !important"] {
            XCTAssertTrue(PlatinumIcons.isBlack(cssColor: black), black)
        }
        for notBlack in ["#fff", "#414141", "#76b5dd", "white", "red", "rgb(0,0,255)", "rgb(26%,0%,0%)", "url(#g)", "#12", "hsl(0, 0%, 0%)"] {
            XCTAssertFalse(PlatinumIcons.isBlack(cssColor: notBlack), notBlack)
        }
    }

    private func png(_ draw: (CGContext) -> Void) throws -> Data {
        let context = try XCTUnwrap(CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        draw(context)
        let image = try XCTUnwrap(context.makeImage())
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    func testRasters() throws {
        let blackCircle = try png { ctx in
            ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            ctx.fillEllipse(in: CGRect(x: 3, y: 3, width: 26, height: 26))
        }
        XCTAssertTrue(PlatinumIcons.isBlack(imageData: blackCircle), "anti-aliased edges are fine")

        let blackWithWhite = try png { ctx in
            ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            ctx.fill(CGRect(x: 8, y: 8, width: 16, height: 16))
        }
        XCTAssertFalse(PlatinumIcons.isBlack(imageData: blackWithWhite))

        let red = try png { ctx in
            ctx.setFillColor(CGColor(red: 0.87, green: 0, blue: 0, alpha: 1))
            ctx.fillEllipse(in: CGRect(x: 3, y: 3, width: 26, height: 26))
        }
        XCTAssertFalse(PlatinumIcons.isBlack(imageData: red))

        let empty = try png { _ in }
        XCTAssertFalse(PlatinumIcons.isBlack(imageData: empty), "nothing drawn")

        XCTAssertFalse(PlatinumIcons.isBlack(imageData: Data("not an image".utf8)))
    }
}
