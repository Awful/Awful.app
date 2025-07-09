//  AwfulRouteTests.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import XCTest
import AwfulCore

final class AwfulRouteTests: XCTestCase {
    
    // MARK: - Awful Scheme URL Tests
    
    func testAwfulSchemeBookmarks() throws {
        let url = URL(string: "awful://bookmarks/")!
        let route = try AwfulRoute(url)
        
        if case .bookmarks = route {
            // Test passes
        } else {
            XCTFail("Expected bookmarks route, got \(route)")
        }
    }
    
    func testAwfulSchemeForumList() throws {
        let url = URL(string: "awful://forums/")!
        let route = try AwfulRoute(url)
        
        if case .forumList = route {
            // Test passes
        } else {
            XCTFail("Expected forumList route, got \(route)")
        }
    }
    
    func testAwfulSchemeSpecificForum() throws {
        let url = URL(string: "awful://forums/123")!
        let route = try AwfulRoute(url)
        
        if case .forum(let id) = route {
            XCTAssertEqual(id, "123")
        } else {
            XCTFail("Expected forum route, got \(route)")
        }
    }
    
    func testAwfulSchemeThreadPage() throws {
        let url = URL(string: "awful://threads/456/pages/5")!
        let route = try AwfulRoute(url)
        
        if case .threadPage(let threadID, let page, _) = route {
            XCTAssertEqual(threadID, "456")
            XCTAssertEqual(page, .specific(5))
        } else {
            XCTFail("Expected threadPage route, got \(route)")
        }
    }
    
    func testAwfulSchemeThreadLastPage() throws {
        let url = URL(string: "awful://threads/456/pages/last")!
        let route = try AwfulRoute(url)
        
        if case .threadPage(let threadID, let page, _) = route {
            XCTAssertEqual(threadID, "456")
            XCTAssertEqual(page, .last)
        } else {
            XCTFail("Expected threadPage route, got \(route)")
        }
    }
    
    func testAwfulSchemeThreadUnreadPage() throws {
        let url = URL(string: "awful://threads/456/pages/unread")!
        let route = try AwfulRoute(url)
        
        if case .threadPage(let threadID, let page, _) = route {
            XCTAssertEqual(threadID, "456")
            XCTAssertEqual(page, .nextUnread)
        } else {
            XCTFail("Expected threadPage route, got \(route)")
        }
    }
    
    func testAwfulSchemePost() throws {
        let url = URL(string: "awful://posts/789")!
        let route = try AwfulRoute(url)
        
        if case .post(let id, _) = route {
            XCTAssertEqual(id, "789")
        } else {
            XCTFail("Expected post route, got \(route)")
        }
    }
    
    func testAwfulSchemeProfile() throws {
        let url = URL(string: "awful://users/123")!
        let route = try AwfulRoute(url)
        
        if case .profile(let userID) = route {
            XCTAssertEqual(userID, "123")
        } else {
            XCTFail("Expected profile route, got \(route)")
        }
    }
    
    func testAwfulSchemeRapSheet() throws {
        let url = URL(string: "awful://banlist/456")!
        let route = try AwfulRoute(url)
        
        if case .rapSheet(let userID) = route {
            XCTAssertEqual(userID, "456")
        } else {
            XCTFail("Expected rapSheet route, got \(route)")
        }
    }
    
    func testAwfulSchemeMessagesList() throws {
        let url = URL(string: "awful://messages/")!
        let route = try AwfulRoute(url)
        
        if case .messagesList = route {
            // Test passes
        } else {
            XCTFail("Expected messagesList route, got \(route)")
        }
    }
    
    func testAwfulSchemeSpecificMessage() throws {
        let url = URL(string: "awful://messages/123")!
        let route = try AwfulRoute(url)
        
        if case .message(let id) = route {
            XCTAssertEqual(id, "123")
        } else {
            XCTFail("Expected message route, got \(route)")
        }
    }
    
    func testAwfulSchemeLepersColony() throws {
        let url = URL(string: "awful://lepers/")!
        let route = try AwfulRoute(url)
        
        if case .lepersColony = route {
            // Test passes
        } else {
            XCTFail("Expected lepersColony route, got \(route)")
        }
    }
    
    func testAwfulSchemeSettings() throws {
        let url = URL(string: "awful://settings/")!
        let route = try AwfulRoute(url)
        
        if case .settings = route {
            // Test passes
        } else {
            XCTFail("Expected settings route, got \(route)")
        }
    }
    
    // MARK: - HTTPS Forums URL Tests
    
    func testHTTPSForumDisplay() throws {
        let url = URL(string: "https://forums.somethingawful.com/forumdisplay.php?forumid=123")!
        let route = try AwfulRoute(url)
        
        if case .forum(let id) = route {
            XCTAssertEqual(id, "123")
        } else {
            XCTFail("Expected forum route, got \(route)")
        }
    }
    
    func testHTTPSShowThread() throws {
        let url = URL(string: "https://forums.somethingawful.com/showthread.php?threadid=456")!
        let route = try AwfulRoute(url)
        
        if case .threadPage(let threadID, let page, _) = route {
            XCTAssertEqual(threadID, "456")
            XCTAssertEqual(page, .first)
        } else {
            XCTFail("Expected threadPage route, got \(route)")
        }
    }
    
    func testHTTPSShowThreadWithPage() throws {
        let url = URL(string: "https://forums.somethingawful.com/showthread.php?threadid=456&pagenumber=5")!
        let route = try AwfulRoute(url)
        
        if case .threadPage(let threadID, let page, _) = route {
            XCTAssertEqual(threadID, "456")
            XCTAssertEqual(page, .specific(5))
        } else {
            XCTFail("Expected threadPage route, got \(route)")
        }
    }
    
    func testHTTPSShowThreadLastPage() throws {
        let url = URL(string: "https://forums.somethingawful.com/showthread.php?threadid=456&goto=lastpost")!
        let route = try AwfulRoute(url)
        
        if case .threadPage(let threadID, let page, _) = route {
            XCTAssertEqual(threadID, "456")
            XCTAssertEqual(page, .last)
        } else {
            XCTFail("Expected threadPage route, got \(route)")
        }
    }
    
    func testHTTPSShowThreadUnreadPage() throws {
        let url = URL(string: "https://forums.somethingawful.com/showthread.php?threadid=456&goto=newpost")!
        let route = try AwfulRoute(url)
        
        if case .threadPage(let threadID, let page, _) = route {
            XCTAssertEqual(threadID, "456")
            XCTAssertEqual(page, .nextUnread)
        } else {
            XCTFail("Expected threadPage route, got \(route)")
        }
    }
    
    func testHTTPSShowPost() throws {
        let url = URL(string: "https://forums.somethingawful.com/showthread.php?goto=post&postid=789")!
        let route = try AwfulRoute(url)
        
        if case .post(let id, _) = route {
            XCTAssertEqual(id, "789")
        } else {
            XCTFail("Expected post route, got \(route)")
        }
    }
    
    func testHTTPSUserProfile() throws {
        let url = URL(string: "https://forums.somethingawful.com/member.php?action=getinfo&userid=123")!
        let route = try AwfulRoute(url)
        
        if case .profile(let userID) = route {
            XCTAssertEqual(userID, "123")
        } else {
            XCTFail("Expected profile route, got \(route)")
        }
    }
    
    func testHTTPSBanList() throws {
        let url = URL(string: "https://forums.somethingawful.com/banlist.php?userid=456")!
        let route = try AwfulRoute(url)
        
        if case .rapSheet(let userID) = route {
            XCTAssertEqual(userID, "456")
        } else {
            XCTFail("Expected rapSheet route, got \(route)")
        }
    }
    
    func testHTTPSPrivateMessages() throws {
        let url = URL(string: "https://forums.somethingawful.com/private.php")!
        let route = try AwfulRoute(url)
        
        if case .messagesList = route {
            // Test passes
        } else {
            XCTFail("Expected messagesList route, got \(route)")
        }
    }
    
    func testHTTPSSpecificPrivateMessage() throws {
        let url = URL(string: "https://forums.somethingawful.com/private.php?action=show&privatemessageid=123")!
        let route = try AwfulRoute(url)
        
        if case .message(let id) = route {
            XCTAssertEqual(id, "123")
        } else {
            XCTFail("Expected message route, got \(route)")
        }
    }
    
    func testHTTPSLepersColony() throws {
        let url = URL(string: "https://forums.somethingawful.com/forumdisplay.php?forumid=268")!
        let route = try AwfulRoute(url)
        
        if case .lepersColony = route {
            // Test passes
        } else {
            XCTFail("Expected lepersColony route, got \(route)")
        }
    }
    
    // MARK: - Safari Extension URL Tests
    
    func testSafariExtensionHTTPS() throws {
        let url = URL(string: "awfulhttps://forums.somethingawful.com/showthread.php?threadid=456")!
        let route = try AwfulRoute(url)
        
        if case .threadPage(let threadID, let page, _) = route {
            XCTAssertEqual(threadID, "456")
            XCTAssertEqual(page, .first)
        } else {
            XCTFail("Expected threadPage route, got \(route)")
        }
    }
    
    func testSafariExtensionHTTP() throws {
        let url = URL(string: "awfulhttp://forums.somethingawful.com/forumdisplay.php?forumid=123")!
        let route = try AwfulRoute(url)
        
        if case .forum(let id) = route {
            XCTAssertEqual(id, "123")
        } else {
            XCTFail("Expected forum route, got \(route)")
        }
    }
    
    // MARK: - Update Seen Parameter Tests
    
    func testUpdateSeenDefault() throws {
        let url = URL(string: "awful://threads/456/pages/5")!
        let route = try AwfulRoute(url)
        
        if case .threadPage(_, _, let updateSeen) = route {
            XCTAssertEqual(updateSeen, .update)
        } else {
            XCTFail("Expected threadPage route, got \(route)")
        }
    }
    
    func testUpdateSeenDisabled() throws {
        let url = URL(string: "awful://threads/456/pages/5?noseen=1")!
        let route = try AwfulRoute(url)
        
        if case .threadPage(_, _, let updateSeen) = route {
            XCTAssertEqual(updateSeen, .ignore)
        } else {
            XCTFail("Expected threadPage route, got \(route)")
        }
    }
    
    func testUpdateSeenPostDefault() throws {
        let url = URL(string: "awful://posts/789")!
        let route = try AwfulRoute(url)
        
        if case .post(_, let updateSeen) = route {
            XCTAssertEqual(updateSeen, .update)
        } else {
            XCTFail("Expected post route, got \(route)")
        }
    }
    
    func testUpdateSeenPostDisabled() throws {
        let url = URL(string: "awful://posts/789?noseen=1")!
        let route = try AwfulRoute(url)
        
        if case .post(_, let updateSeen) = route {
            XCTAssertEqual(updateSeen, .ignore)
        } else {
            XCTFail("Expected post route, got \(route)")
        }
    }
    
    // MARK: - Thread Page Single User Tests
    
    func testThreadPageSingleUser() throws {
        let url = URL(string: "awful://threads/456/pages/5?userid=123")!
        let route = try AwfulRoute(url)
        
        if case .threadPageSingleUser(let threadID, let userID, let page, _) = route {
            XCTAssertEqual(threadID, "456")
            XCTAssertEqual(userID, "123")
            XCTAssertEqual(page, .specific(5))
        } else {
            XCTFail("Expected threadPageSingleUser route, got \(route)")
        }
    }
    
    func testHTTPSThreadPageSingleUser() throws {
        let url = URL(string: "https://forums.somethingawful.com/showthread.php?threadid=456&userid=123&pagenumber=5")!
        let route = try AwfulRoute(url)
        
        if case .threadPageSingleUser(let threadID, let userID, let page, _) = route {
            XCTAssertEqual(threadID, "456")
            XCTAssertEqual(userID, "123")
            XCTAssertEqual(page, .specific(5))
        } else {
            XCTFail("Expected threadPageSingleUser route, got \(route)")
        }
    }
    
    // MARK: - Invalid URL Tests
    
    func testInvalidScheme() {
        let url = URL(string: "https://google.com")!
        XCTAssertThrowsError(try AwfulRoute(url))
    }
    
    func testInvalidAwfulPath() {
        let url = URL(string: "awful://invalid/path")!
        XCTAssertThrowsError(try AwfulRoute(url))
    }
    
    func testInvalidForumID() {
        let url = URL(string: "awful://forums/invalid")!
        XCTAssertThrowsError(try AwfulRoute(url))
    }
    
    func testInvalidThreadID() {
        let url = URL(string: "awful://threads/invalid/pages/1")!
        XCTAssertThrowsError(try AwfulRoute(url))
    }
    
    func testInvalidPageNumber() {
        let url = URL(string: "awful://threads/456/pages/invalid")!
        XCTAssertThrowsError(try AwfulRoute(url))
    }
    
    func testInvalidPostID() {
        let url = URL(string: "awful://posts/invalid")!
        XCTAssertThrowsError(try AwfulRoute(url))
    }
    
    func testInvalidUserID() {
        let url = URL(string: "awful://users/invalid")!
        XCTAssertThrowsError(try AwfulRoute(url))
    }
    
    // MARK: - Edge Cases
    
    func testEmptyPath() {
        let url = URL(string: "awful://")!
        XCTAssertThrowsError(try AwfulRoute(url))
    }
    
    func testMissingParameters() {
        let url = URL(string: "https://forums.somethingawful.com/showthread.php")!
        XCTAssertThrowsError(try AwfulRoute(url))
    }
    
    func testExtraParameters() throws {
        let url = URL(string: "awful://threads/456/pages/5?extra=value&another=param")!
        let route = try AwfulRoute(url)
        
        if case .threadPage(let threadID, let page, _) = route {
            XCTAssertEqual(threadID, "456")
            XCTAssertEqual(page, .specific(5))
        } else {
            XCTFail("Expected threadPage route, got \(route)")
        }
    }
    
    func testCaseInsensitivity() throws {
        let url = URL(string: "awful://THREADS/456/PAGES/LAST")!
        let route = try AwfulRoute(url)
        
        if case .threadPage(let threadID, let page, _) = route {
            XCTAssertEqual(threadID, "456")
            XCTAssertEqual(page, .last)
        } else {
            XCTFail("Expected threadPage route, got \(route)")
        }
    }
}

// MARK: - ThreadPage Equatable Extension

extension ThreadPage: Equatable {
    public static func == (lhs: ThreadPage, rhs: ThreadPage) -> Bool {
        switch (lhs, rhs) {
        case (.first, .first),
             (.last, .last),
             (.nextUnread, .nextUnread):
            return true
        case (.specific(let lhsPage), .specific(let rhsPage)):
            return lhsPage == rhsPage
        default:
            return false
        }
    }
}

// MARK: - UpdateSeen Equatable Extension

extension UpdateSeen: Equatable {
    public static func == (lhs: UpdateSeen, rhs: UpdateSeen) -> Bool {
        switch (lhs, rhs) {
        case (.update, .update),
             (.ignore, .ignore):
            return true
        default:
            return false
        }
    }
}