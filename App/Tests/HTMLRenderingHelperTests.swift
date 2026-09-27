//  HTMLRenderingHelperTests.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import HTMLReader
import XCTest

final class HTMLRenderingHelperTests: XCTestCase {
    func testSingleMention() {
        func makeDocument(username: String, before: String = "", after: String = "") -> HTMLDocument {
            return HTMLDocument(string: "\(before)\(username)\(after)")
        }
        
        do {
            let simpleCallout = makeDocument(username: "jerkstore")
            simpleCallout.identifyMentionsOfUser(named: "jerkstore", shouldHighlight: false)
            XCTAssertEqual(simpleCallout.bodyElement!.innerHTML, """
                <span class="mention">jerkstore</span>
                """)
        }
        
        do {
            let calloutAtEnd = makeDocument(username: "jerky store", before: "la de da ")
            calloutAtEnd.identifyMentionsOfUser(named: "jerky store", shouldHighlight: true)
            XCTAssertEqual(calloutAtEnd.bodyElement!.innerHTML, """
                la de da <span class="mention highlight">jerky store</span>
                """)
        }
        
        do {
            let calloutInMiddle = makeDocument(username: "jerk store jr", before: "la de da ", after: " do re mi")
            calloutInMiddle.identifyMentionsOfUser(named: "jerk store jr", shouldHighlight: false)
            XCTAssertEqual(calloutInMiddle.bodyElement!.innerHTML, """
                la de da <span class="mention">jerk store jr</span> do re mi
                """)
        }
    }
    
    func testMultipleMentions() {
        let doc = HTMLDocument(string: """
            jerkstore, you are a jerkstore. I just wanted you, jerkstore, to know that!
            """)
        doc.identifyMentionsOfUser(named: "jerkstore", shouldHighlight: true)
        XCTAssertEqual(doc.bodyElement!.innerHTML, """
            <span class="mention highlight">jerkstore</span>, you are a \
            <span class="mention highlight">jerkstore</span>. I just wanted you, \
            <span class="mention highlight">jerkstore</span>, to know that!
            """)
    }
    
    func testProblematicSymbolsInUsername() {
        let doc = HTMLDocument(string: """
            hello there ^cool>$user\\"
            """)
        doc.identifyMentionsOfUser(named: "^cool>$user\\\"", shouldHighlight: false)
        XCTAssertEqual(doc.bodyElement!.innerHTML, """
            hello there <span class="mention">^cool&gt;$user\\\"</span>
            """)
    }

    func testEmbedVideosForIncompleteYouTubeURL() {
        let doc = HTMLDocument(string: """
            <a href="https://youtu.be" target="_blank" rel="nofollow">https://youtu.be</a>
            """)
        doc.embedVideos()
        XCTAssertNil(doc.firstNode(matchingParsedSelector: .cached("iframe")))
        XCTAssertNotNil(doc.firstNode(matchingParsedSelector: .cached("a")))
    }

    func testEagerImageAllowanceIsSharedAcrossPosts() {
        func post(imageCount: Int) -> HTMLDocument {
            HTMLDocument(string: (0..<imageCount).map { #"<img src="https://example.com/\#($0).png">"# }.joined())
        }
        func lazyImageCount(in document: HTMLDocument) -> Int {
            document.nodes(matchingParsedSelector: .cached("img[loading='lazy']")).count
        }

        var allowance = 3
        let first = post(imageCount: 2)
        let second = post(imageCount: 2)
        let third = post(imageCount: 1)
        first.processImgTags(shouldLinkifyNonSmilies: false, eagerImageAllowance: &allowance)
        second.processImgTags(shouldLinkifyNonSmilies: false, eagerImageAllowance: &allowance)
        third.processImgTags(shouldLinkifyNonSmilies: false, eagerImageAllowance: &allowance)

        XCTAssertEqual(lazyImageCount(in: first), 0)
        XCTAssertEqual(lazyImageCount(in: second), 1)
        XCTAssertEqual(lazyImageCount(in: third), 1)
        XCTAssertEqual(allowance, 0)
    }

    func testStoppedGIFKeepsLazyLoading() {
        let doc = HTMLDocument(string: #"<img src="https://i.imgur.com/abc.gif" loading="lazy">"#)
        doc.stopGIFAutoplay()
        let poster = doc.firstNode(matchingParsedSelector: .cached("img.posterized"))
        XCTAssertEqual(poster?["src"], "https://i.imgur.com/abch.jpg")
        XCTAssertEqual(poster?["loading"], "lazy")
    }

    func testEmbeddedYouTubeLinkLoadsLazily() {
        let url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        let doc = HTMLDocument(string: #"<a href="\#(url)">\#(url)</a>"#)
        doc.embedVideos()
        let iframe = doc.firstNode(matchingParsedSelector: .cached("iframe"))
        XCTAssertNotNil(iframe)
        XCTAssertEqual(iframe?["loading"], "lazy")
    }

    func testEmbeddedImgurVideoWaitsForPlayback() {
        let url = "https://i.imgur.com/abc.gifv"
        let doc = HTMLDocument(string: #"<a href="\#(url)">\#(url)</a>"#)
        doc.embedVideos()
        let video = doc.firstNode(matchingParsedSelector: .cached("video"))
        XCTAssertEqual(video?["preload"], "none")
        XCTAssertEqual(video?["poster"], "https://i.imgur.com/abch.jpg")
    }

    func testPostImagesDecodeAsynchronously() {
        let doc = HTMLDocument(string: #"<img src="https://example.com/a.png">"#)
        doc.processImgTags(shouldLinkifyNonSmilies: false)
        XCTAssertEqual(doc.firstNode(matchingParsedSelector: .cached("img"))?["decoding"], "async")
    }
}
