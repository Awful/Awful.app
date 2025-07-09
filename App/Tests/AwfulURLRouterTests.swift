//  AwfulURLRouterTests.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import XCTest
import AwfulCore
import CoreData

final class AwfulURLRouterTests: XCTestCase {
    
    var mockCoordinator: MockMainCoordinator!
    var mockRootViewController: UIViewController!
    var mockContext: NSManagedObjectContext!
    var router: AwfulURLRouter!
    
    override func setUp() {
        super.setUp()
        mockCoordinator = MockMainCoordinator()
        mockRootViewController = UIViewController()
        mockContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        
        router = AwfulURLRouter(
            rootViewController: mockRootViewController,
            managedObjectContext: mockContext
        )
        router.coordinator = mockCoordinator
    }
    
    override func tearDown() {
        mockCoordinator = nil
        mockRootViewController = nil
        mockContext = nil
        router = nil
        super.tearDown()
    }
    
    // MARK: - URL Parsing Tests
    
    func testAwfulSchemeURLParsing() {
        XCTAssertNoThrow(try AwfulRoute(URL(string: "awful://bookmarks/")!))
        XCTAssertNoThrow(try AwfulRoute(URL(string: "awful://forums/")!))
        XCTAssertNoThrow(try AwfulRoute(URL(string: "awful://forums/123")!))
        XCTAssertNoThrow(try AwfulRoute(URL(string: "awful://threads/456/pages/5")!))
        XCTAssertNoThrow(try AwfulRoute(URL(string: "awful://posts/789")!))
        XCTAssertNoThrow(try AwfulRoute(URL(string: "awful://users/123")!))
        XCTAssertNoThrow(try AwfulRoute(URL(string: "awful://banlist/456")!))
        XCTAssertNoThrow(try AwfulRoute(URL(string: "awful://messages/")!))
        XCTAssertNoThrow(try AwfulRoute(URL(string: "awful://messages/123")!))
        XCTAssertNoThrow(try AwfulRoute(URL(string: "awful://lepers/")!))
        XCTAssertNoThrow(try AwfulRoute(URL(string: "awful://settings/")!))
    }
    
    func testHTTPSForumsURLParsing() {
        XCTAssertNoThrow(try AwfulRoute(URL(string: "https://forums.somethingawful.com/")!))
        XCTAssertNoThrow(try AwfulRoute(URL(string: "https://forums.somethingawful.com/forumdisplay.php?forumid=123")!))
        XCTAssertNoThrow(try AwfulRoute(URL(string: "https://forums.somethingawful.com/showthread.php?threadid=456")!))
        XCTAssertNoThrow(try AwfulRoute(URL(string: "https://forums.somethingawful.com/showthread.php?threadid=456&pagenumber=5")!))
        XCTAssertNoThrow(try AwfulRoute(URL(string: "https://forums.somethingawful.com/showthread.php?goto=post&postid=789")!))
        XCTAssertNoThrow(try AwfulRoute(URL(string: "https://forums.somethingawful.com/member.php?action=getinfo&userid=123")!))
        XCTAssertNoThrow(try AwfulRoute(URL(string: "https://forums.somethingawful.com/banlist.php?userid=456")!))
        XCTAssertNoThrow(try AwfulRoute(URL(string: "https://forums.somethingawful.com/private.php")!))
        XCTAssertNoThrow(try AwfulRoute(URL(string: "https://forums.somethingawful.com/private.php?action=show&privatemessageid=123")!))
        XCTAssertNoThrow(try AwfulRoute(URL(string: "https://forums.somethingawful.com/forumdisplay.php?forumid=268")!))
    }
    
    func testSafariExtensionURLParsing() {
        XCTAssertNoThrow(try AwfulRoute(URL(string: "awfulhttps://forums.somethingawful.com/showthread.php?threadid=456")!))
        XCTAssertNoThrow(try AwfulRoute(URL(string: "awfulhttp://forums.somethingawful.com/forumdisplay.php?forumid=123")!))
    }
    
    func testInvalidURLParsing() {
        XCTAssertThrowsError(try AwfulRoute(URL(string: "https://google.com")!))
        XCTAssertThrowsError(try AwfulRoute(URL(string: "awful://invalid/")!))
        XCTAssertThrowsError(try AwfulRoute(URL(string: "file://local/path")!))
    }
    
    // MARK: - Route Type Tests
    
    func testBookmarksRoute() throws {
        let url = URL(string: "awful://bookmarks/")!
        let route = try AwfulRoute(url)
        
        if case .bookmarks = route {
            // Test passes
        } else {
            XCTFail("Expected bookmarks route, got \(route)")
        }
    }
    
    func testForumRoute() throws {
        let url = URL(string: "awful://forums/123")!
        let route = try AwfulRoute(url)
        
        if case .forum(let id) = route {
            XCTAssertEqual(id, "123")
        } else {
            XCTFail("Expected forum route, got \(route)")
        }
    }
    
    func testThreadPageRoute() throws {
        let url = URL(string: "awful://threads/456/pages/5")!
        let route = try AwfulRoute(url)
        
        if case .threadPage(let threadID, let page, _) = route {
            XCTAssertEqual(threadID, "456")
            XCTAssertEqual(page, .specific(5))
        } else {
            XCTFail("Expected threadPage route, got \(route)")
        }
    }
    
    func testPostRoute() throws {
        let url = URL(string: "awful://posts/789")!
        let route = try AwfulRoute(url)
        
        if case .post(let id, _) = route {
            XCTAssertEqual(id, "789")
        } else {
            XCTFail("Expected post route, got \(route)")
        }
    }
    
    func testProfileRoute() throws {
        let url = URL(string: "awful://users/123")!
        let route = try AwfulRoute(url)
        
        if case .profile(let userID) = route {
            XCTAssertEqual(userID, "123")
        } else {
            XCTFail("Expected profile route, got \(route)")
        }
    }
    
    func testRapSheetRoute() throws {
        let url = URL(string: "awful://banlist/456")!
        let route = try AwfulRoute(url)
        
        if case .rapSheet(let userID) = route {
            XCTAssertEqual(userID, "456")
        } else {
            XCTFail("Expected rapSheet route, got \(route)")
        }
    }
    
    func testMessageRoute() throws {
        let url = URL(string: "awful://messages/123")!
        let route = try AwfulRoute(url)
        
        if case .message(let id) = route {
            XCTAssertEqual(id, "123")
        } else {
            XCTFail("Expected message route, got \(route)")
        }
    }
    
    // MARK: - URL Routing Tests
    
    func testRouteBookmarks() {
        let route = AwfulRoute.bookmarks
        let result = router.route(route)
        
        XCTAssertTrue(result)
        XCTAssertEqual(mockCoordinator.navigatedTab, .bookmarks)
    }
    
    func testRouteForumList() {
        let route = AwfulRoute.forumList
        let result = router.route(route)
        
        XCTAssertTrue(result)
        XCTAssertEqual(mockCoordinator.navigatedTab, .forums)
    }
    
    func testRouteMessagesList() {
        let route = AwfulRoute.messagesList
        let result = router.route(route)
        
        XCTAssertTrue(result)
        XCTAssertEqual(mockCoordinator.navigatedTab, .messages)
    }
    
    func testRouteLepersColony() {
        let route = AwfulRoute.lepersColony
        let result = router.route(route)
        
        XCTAssertTrue(result)
        XCTAssertEqual(mockCoordinator.navigatedTab, .lepersColony)
    }
    
    func testRouteSettings() {
        let route = AwfulRoute.settings
        let result = router.route(route)
        
        XCTAssertTrue(result)
        XCTAssertEqual(mockCoordinator.navigatedTab, .settings)
    }
    
    // MARK: - Edge Cases
    
    func testRouteWithoutCoordinator() {
        router.coordinator = nil
        let route = AwfulRoute.bookmarks
        let result = router.route(route)
        
        // Should fall back to UIKit navigation
        XCTAssertTrue(result)
    }
    
    func testRouteWithInvalidData() {
        let route = AwfulRoute.forum(id: "invalid")
        let result = router.route(route)
        
        // Should handle gracefully
        XCTAssertFalse(result)
    }
    
    func testConcurrentRouting() {
        let expectation = self.expectation(description: "Concurrent routing")
        expectation.expectedFulfillmentCount = 3
        
        let queue = DispatchQueue.global(qos: .background)
        
        queue.async {
            let result = self.router.route(.bookmarks)
            XCTAssertTrue(result)
            expectation.fulfill()
        }
        
        queue.async {
            let result = self.router.route(.forumList)
            XCTAssertTrue(result)
            expectation.fulfill()
        }
        
        queue.async {
            let result = self.router.route(.settings)
            XCTAssertTrue(result)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
    }
}

// MARK: - Mock Coordinator

final class MockMainCoordinator: MainCoordinator {
    
    var isTabBarHidden = false
    var path = NavigationPath()
    var sidebarPath = NavigationPath()
    
    var navigatedTab: MainTab?
    var navigatedThread: AwfulThread?
    var navigatedForum: Forum?
    var navigatedMessage: PrivateMessage?
    var navigatedPage: ThreadPage?
    var navigatedAuthor: User?
    var presentedSearch = false
    var presentedCompose = false
    var presentedComposeThread = false
    var lastEditTab: MainTab?
    
    func presentSearch() {
        presentedSearch = true
    }
    
    func handleEditAction(for tab: MainTab) {
        lastEditTab = tab
    }
    
    func presentCompose(for tab: MainTab) {
        presentedCompose = true
    }
    
    func navigateToThread(_ thread: AwfulThread) {
        navigatedThread = thread
    }
    
    func navigateToThread(_ thread: AwfulThread, page: ThreadPage) {
        navigatedThread = thread
        navigatedPage = page
    }
    
    func navigateToThread(_ thread: AwfulThread, page: ThreadPage, author: User?) {
        navigatedThread = thread
        navigatedPage = page
        navigatedAuthor = author
    }
    
    func navigateToForum(_ forum: Forum) {
        navigatedForum = forum
    }
    
    func navigateToPrivateMessage(_ message: PrivateMessage) {
        navigatedMessage = message
    }
    
    func presentComposeThread(for forum: Forum) {
        presentedComposeThread = true
        navigatedForum = forum
    }
    
    func shouldHideTabBar(isInSidebar: Bool) -> Bool {
        return isTabBarHidden
    }
    
    // Helper methods for testing
    func navigateToTab(_ tab: MainTab) {
        navigatedTab = tab
    }
}

// MARK: - MainTab Extension for Testing

extension MainTab: Equatable {
    public static func == (lhs: MainTab, rhs: MainTab) -> Bool {
        switch (lhs, rhs) {
        case (.forums, .forums),
             (.bookmarks, .bookmarks),
             (.messages, .messages),
             (.lepersColony, .lepersColony),
             (.settings, .settings):
            return true
        default:
            return false
        }
    }
}