//  PostIconListScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader

public struct PostIconListScrapeResult: ScrapeResult {
    public let primaryIcons: [PostIcon]
    public let secondaryIcons: [PostIcon]
    public let selectedPrimaryIconFormName: String
    public let selectedSecondaryIconFormName: String

    public init(_ html: HTMLNode, url: URL?) throws {
        let primaryDivs = html.nodes(matchingSelector: "div.posticon")
        guard !primaryDivs.isEmpty else {
            throw ScrapingError.missingExpectedElement("div.posticon")
        }

        primaryIcons = primaryDivs.compactMap { try? PostIcon(div: $0) }

        selectedPrimaryIconFormName = try primaryDivs.first!
            .requiredNode(matchingSelector: "input[name]")["name"]!

        let secondaryInputs = html.nodes(matchingSelector: "input[type = 'radio']:not([name = 'iconid'])")
        let secondaryImages = html.nodes(matchingSelector: "input[type = 'radio']:not([name = 'iconid']) + img")
        guard secondaryInputs.count == secondaryImages.count else {
            secondaryIcons = []
            selectedSecondaryIconFormName = ""
            return
        }

        secondaryIcons = zip(secondaryInputs, secondaryImages).compactMap {
            try? PostIcon(input: $0, image: $1)
        }

        selectedSecondaryIconFormName = secondaryInputs.first?["name"] ?? ""
    }
}

private extension PostIcon {
    init(div: HTMLElement) throws {
        id = try div.requiredNode(matchingSelector: "input[value]")["value"]!
        guard
            let src = try div.requiredNode(matchingSelector: "img[src]")["src"],
            let url = URL(string: src)
            else { throw ScrapingError.missingExpectedElement("img[src = url]") }
        self.url = url
    }

    init(input: HTMLElement, image: HTMLElement) throws {
        guard let id = input["value"] else {
            throw ScrapingError.missingExpectedElement("input[value]")
        }
        self.id = id

        guard let src = image["src"] else {
            throw ScrapingError.missingExpectedElement("img[src]")
        }
        guard let url = URL(string: src) else {
            throw ScrapingError.missingExpectedElement("img[src = url]")
        }
        self.url = url
    }
}
