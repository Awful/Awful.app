//  PostIconListScrapingTests.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class PostIconListScrapingTests: XCTestCase {
    func testNewThread() throws {
        let result = try scrapeHTMLFixture(PostIconListScrapeResult.self, named: "newthread")
        XCTAssertEqual(result.primaryIcons.count, 51)
        XCTAssertEqual(result.selectedPrimaryIconFormName, "iconid")
        XCTAssert(result.secondaryIcons.isEmpty)
    }

    func testAskTellThread() throws {
        let result = try scrapeHTMLFixture(PostIconListScrapeResult.self, named: "newthread-at")
        XCTAssertEqual(result.primaryIcons.count, 55)
        XCTAssertEqual(result.selectedSecondaryIconFormName, "tma_ama")

        let secondaryImageNames = result.secondaryIcons
            .compactMap { $0.url }
            .map(ThreadTag.imageName)
            .sorted()
        XCTAssertEqual(secondaryImageNames, ["ama", "tma"])
    }

    func testSAMartThread() throws {
        let result = try scrapeHTMLFixture(PostIconListScrapeResult.self, named: "newthread-samart")
        XCTAssertEqual(result.primaryIcons.count, 69)
        XCTAssertEqual(result.selectedSecondaryIconFormName, "samart_tag")

        let secondaryImageNames = result.secondaryIcons
            .compactMap { $0.url }
            .map(ThreadTag.imageName)
            .sorted()
        XCTAssertEqual(secondaryImageNames, ["icon-37-selling", "icon-38-buying", "icon-46-trading", "icon-52-trading"])
    }
}
