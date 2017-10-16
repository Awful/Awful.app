//  Helpers.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import HTMLReader

// Without import UIKit somewhere in this test bundle, it refuses to load. Nothing here actually needs UIKit.
import UIKit

func fixtureNamed(_ basename: String) -> HTMLDocument {
    let fixtureURL = Bundle(for: DatabaseUnavailableScrapingTests.self).url(forResource: basename, withExtension: "html", subdirectory: "Fixtures")!
    var fixtureHTML : NSString = NSString()
    do {
        fixtureHTML = try NSString(contentsOf: fixtureURL, encoding: String.Encoding.windowsCP1252.rawValue)
    }
    catch {
        fatalError("error loading fixture from \(fixtureURL): \(error)")
    }
    
    return HTMLDocument(string: (fixtureHTML as String?)!)
}

func scrapeFixture<T: ScrapeResult>(named fixtureName: String) throws -> T {
    return try T(fixtureNamed(fixtureName), url: URL(string: "https://example.com/?perpage=40"))
}

func scrapeForm(matchingSelector selector: String, inFixtureNamed fixtureName: String) throws -> Form {
    let doc = fixtureNamed(fixtureName)
    return try Form(doc.requiredNode(matchingSelector: selector), url: URL(string: "https://example.com/?perpage=40"))
}


func makeUTCDefaultTimeZone() {
    NSTimeZone.default = TimeZone(secondsFromGMT: 0)!
}


extension Form {
    var textboxes: [Form.Control] {
        return controls.filter { control in
            switch control {
            case .text: return true
            default: return false
            }
        }
    }
}
