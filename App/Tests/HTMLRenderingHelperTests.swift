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
}
